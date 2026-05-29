import WebKit

/// Non-ad-blocking page tweaks that make YouTube behave like a native player:
///  - keep audio playing when the app is backgrounded / screen is locked
///  - hide the "Open app" promo that nudges users to the official YouTube app
///  - trigger Picture-in-Picture on demand
///
/// These are injected regardless of the ad-block toggle since they are about
/// playback UX, not blocking ads.
enum WebEnhancements {

    // MARK: - Background playback

    /// YouTube pauses the video when it thinks the page is hidden (Page
    /// Visibility API + pagehide). We spoof "always visible" and swallow those
    /// events so playback continues with the screen off / app in background.
    /// Injected at documentStart so it runs before YouTube's own scripts.
    static let backgroundPlayJS = """
    (function () {
      'use strict';
      try {
        Object.defineProperty(document, 'visibilityState', { get: function () { return 'visible'; } });
        Object.defineProperty(document, 'webkitVisibilityState', { get: function () { return 'visible'; } });
        Object.defineProperty(document, 'hidden', { get: function () { return false; } });
        Object.defineProperty(document, 'webkitHidden', { get: function () { return false; } });
      } catch (e) {}
      var swallow = function (e) { e.stopImmediatePropagation(); };
      window.addEventListener('visibilitychange', swallow, true);
      document.addEventListener('visibilitychange', swallow, true);
      window.addEventListener('webkitvisibilitychange', swallow, true);
      window.addEventListener('pagehide', swallow, true);
      window.addEventListener('blur', swallow, true);
    })();
    """

    static func backgroundPlayScript() -> WKUserScript {
        WKUserScript(source: backgroundPlayJS,
                     injectionTime: .atDocumentStart,
                     forMainFrameOnly: false)
    }

    // MARK: - Cosmetic cleanup ("Open app" banner)

    /// Hides the "Open app" / "Mở ứng dụng" prompts that YouTube web shows in
    /// a browser. Runs on a short interval because YouTube re-renders them.
    static let hideOpenAppJS = """
    (function () {
      'use strict';
      function hide() {
        document.querySelectorAll('a, button').forEach(function (el) {
          var t = (el.textContent || '').trim();
          var aria = (el.getAttribute('aria-label') || '');
          if (t === 'Mở ứng dụng' || t === 'Open app' ||
              /mở ứng dụng/i.test(aria) || /open app/i.test(aria)) {
            el.style.display = 'none';
          }
        });
        ['ytm-app-promo-renderer', 'ytm-mealbar-promo-renderer',
         '#app-promo', 'ytd-app-promo-renderer'].forEach(function (sel) {
          document.querySelectorAll(sel).forEach(function (n) { n.remove(); });
        });
      }
      hide();
      setInterval(hide, 800);
    })();
    """

    static func hideOpenAppScript() -> WKUserScript {
        WKUserScript(source: hideOpenAppJS,
                     injectionTime: .atDocumentEnd,
                     forMainFrameOnly: false)
    }

    // MARK: - Keep the playlist alive

    /// On YouTube web, accidentally closing the queue panel drops the `list=`
    /// param from the URL, so "play through the playlist" stops. We keep it
    /// alive two ways, neither of which reloads the page (so audio is never
    /// interrupted):
    ///
    ///  1) Selector-free safety net: the close action keeps the SAME video
    ///     (`v=` unchanged) but removes `list=`. When we see exactly that, we
    ///     put `list=` back via history.replaceState. Navigating to a *different*
    ///     video changes `v=`, so this never forces the old list onto unrelated
    ///     videos.
    ///  2) Best-effort: swallow taps on the queue panel's close ("X") button so
    ///     the list isn't dismissed in the first place. Scoped to the playlist
    ///     container, so wrong selectors simply do nothing (no over-blocking).
    static let keepPlaylistJS = """
    (function () {
      'use strict';
      var lastV = null, lastList = null, busy = false;

      function read() {
        try {
          var p = new URLSearchParams(location.search);
          return { v: p.get('v'), list: p.get('list') };
        } catch (e) { return { v: null, list: null }; }
      }

      function sync() {
        if (busy) return;
        var c = read();
        // Same video, list just disappeared -> the queue was closed. Restore it.
        if (c.v && c.v === lastV && lastList && !c.list && /\\/watch/.test(location.pathname)) {
          try {
            busy = true;
            var u = new URL(location.href);
            u.searchParams.set('list', lastList);
            history.replaceState(history.state, '', u.toString());
            c.list = lastList;
          } catch (e) {} finally { busy = false; }
        }
        lastV = c.v;
        if (c.list) lastList = c.list;
      }

      ['pushState', 'replaceState'].forEach(function (m) {
        var orig = history[m];
        history[m] = function () {
          var r = orig.apply(this, arguments);
          try { sync(); } catch (e) {}
          return r;
        };
      });
      window.addEventListener('popstate', sync, true);
      setInterval(sync, 500);   // catch URL changes that skip the history API
      sync();

      // (2) Block accidental taps on the queue's close button.
      function isQueueClose(node) {
        var btn = node && node.closest && node.closest('button, a, [role=button]');
        if (!btn) return false;
        var inQueue = btn.closest(
          'ytm-playlist-panel-renderer, [class*="playlist-panel"], [class*="watch-queue"]');
        if (!inQueue) return false;
        var label = (btn.getAttribute('aria-label') || '').toLowerCase();
        return /close|dismiss|đóng|hide|ẩn/.test(label);
      }
      document.addEventListener('click', function (e) {
        try {
          if (isQueueClose(e.target)) { e.stopImmediatePropagation(); e.preventDefault(); }
        } catch (err) {}
      }, true);
    })();
    """

    static func keepPlaylistScript() -> WKUserScript {
        WKUserScript(source: keepPlaylistJS,
                     injectionTime: .atDocumentStart,
                     forMainFrameOnly: false)
    }

    // MARK: - Picture-in-Picture

    /// Floating PiP button injected into the page (since we removed the native
    /// toolbar). It appears whenever a real video is loaded and toggles system
    /// Picture-in-Picture on tap. Selector-free — it just appends a fixed-
    /// position button to <body>, so it survives YouTube UI changes.
    static let pipButtonJS = """
    (function () {
      'use strict';
      var ID = '__vt_pip_btn';

      function ensureButton() {
        var existing = document.getElementById(ID);
        if (existing) return existing;
        if (!document.body) return null;
        var b = document.createElement('button');
        b.id = ID;
        b.setAttribute('aria-label', 'Picture in Picture');
        b.innerHTML =
          '<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">' +
          '<path d="M19 7h-8v6h8V7zm2-4H3c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h18' +
          'c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H3V5h18v14z"/></svg>';
        b.style.cssText =
          'position:fixed;z-index:2147483647;bottom:96px;right:12px;' +
          'width:44px;height:44px;border-radius:22px;border:none;' +
          'background:rgba(0,0,0,0.55);color:#fff;display:none;' +
          'align-items:center;justify-content:center;padding:0;cursor:pointer;' +
          '-webkit-tap-highlight-color:transparent;';
        b.addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          var v = document.querySelector('video');
          if (v && typeof v.webkitSetPresentationMode === 'function') {
            v.webkitSetPresentationMode(
              v.webkitPresentationMode === 'picture-in-picture' ? 'inline' : 'picture-in-picture');
          }
        }, true);
        document.body.appendChild(b);
        return b;
      }

      function tick() {
        var b = ensureButton();
        if (!b) return;
        var v = document.querySelector('video');
        var ready = v && v.readyState > 0 && isFinite(v.duration) && v.duration > 0;
        b.style.display = ready ? 'flex' : 'none';
      }

      setInterval(tick, 800);
      tick();
    })();
    """

    static func pipButtonScript() -> WKUserScript {
        WKUserScript(source: pipButtonJS,
                     injectionTime: .atDocumentEnd,
                     forMainFrameOnly: true)
    }

    /// JS to push the current <video> into PiP using the WebKit presentation
    /// API (YouTube's custom controls don't expose a native PiP button).
    static let enterPiPJS = """
    (function () {
      var v = document.querySelector('video');
      if (v && typeof v.webkitSetPresentationMode === 'function') {
        v.webkitSetPresentationMode(
          v.webkitPresentationMode === 'picture-in-picture' ? 'inline' : 'picture-in-picture'
        );
      }
    })();
    """

    /// Auto-PiP fired when the app is backgrounded: only *enter* PiP, and only
    /// when a video is actually playing and not already in PiP. Keeps audio
    /// alive with the screen off without the user tapping the PiP button.
    static let autoEnterPiPJS = """
    (function () {
      var v = document.querySelector('video');
      if (v && !v.paused && typeof v.webkitSetPresentationMode === 'function'
          && v.webkitPresentationMode !== 'picture-in-picture') {
        v.webkitSetPresentationMode('picture-in-picture');
      }
    })();
    """
}

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
      var MODAL_PATTERN = /watch in youtube app|get the best experience|open in app|mở trong ứng dụng youtube/i;

      // Component selectors to remove unconditionally.
      var PROMO_SELS = [
        'ytm-app-promo-renderer', 'ytm-mealbar-promo-renderer',
        'ytm-confirmation-dialog-renderer', 'ytm-bottom-sheet-container',
        '#app-promo', 'ytd-app-promo-renderer'
      ];

      // Scrim/backdrop overlays that block touches after modal removal.
      var SCRIM_SELS = [
        'ytm-overlay-panel-scrim', 'tp-yt-iron-overlay-backdrop',
        'iron-overlay-backdrop', 'ytm-bottom-sheet-overlay',
        '[class*="scrim"]', '[class*="backdrop"]'
      ];

      var OPEN_APP_TEXTS = [
        'mở ứng dụng', 'open app', 'watch in youtube app',
        'xem trong ứng dụng youtube', 'open in app', 'mở trong ứng dụng'
      ];

      function isOpenAppEl(el) {
        var t = (el.textContent || '').trim().toLowerCase();
        var aria = (el.getAttribute('aria-label') || '').toLowerCase();
        return OPEN_APP_TEXTS.some(function (s) { return t === s || aria.indexOf(s) !== -1; });
      }

      function hide() {
        // 1. Remove known promo components.
        PROMO_SELS.forEach(function (sel) {
          document.querySelectorAll(sel).forEach(function (n) { n.remove(); });
        });

        // 2. Remove scrim/backdrop that blocks all touches after modal removal.
        SCRIM_SELS.forEach(function (sel) {
          document.querySelectorAll(sel).forEach(function (n) { n.remove(); });
        });

        // 3. Reset scroll/pointer locks YouTube sets when a modal opens.
        document.body.style.overflow = '';
        document.body.style.position = '';
        document.documentElement.style.overflow = '';

        // 4. Find role="dialog" containing promo text — click × or remove.
        document.querySelectorAll('[role="dialog"], [role="alertdialog"]').forEach(function (modal) {
          if (!MODAL_PATTERN.test(modal.textContent || '')) return;
          var closeBtn = modal.querySelector(
            'button[aria-label="Close"], button[aria-label="Dismiss"], button[aria-label="Đóng"]'
          );
          if (closeBtn) { closeBtn.click(); } else { modal.remove(); }
        });

        // 5. Individual button fallback — just hide, no DOM walk.
        document.querySelectorAll('a, button').forEach(function (el) {
          if (isOpenAppEl(el)) el.style.display = 'none';
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

    // MARK: - Floating action button (PiP + Playlist)

    /// Single draggable FAB. Tap → PiP. Long-press → popup menu with PiP and
    /// (when a playlist is active and the panel is closed) Playlist buttons.
    /// Position is persisted in localStorage and the button snaps to the nearest
    /// horizontal edge on release.
    static let floatingMenuJS = """
    (function () {
      'use strict';
      var FAB_ID  = '__vt_fab';
      var MENU_ID = '__vt_fab_menu';

      var ICON_PIP =
        '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">' +
        '<path d="M19 7h-8v6h8V7zm2-4H3c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h18' +
        'c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H3V5h18v14z"/></svg>';
      var ICON_PL =
        '<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">' +
        '<path d="M3 5h18v2H3zm0 4h12v2H3zm0 4h18v2H3zm0 4h12v2H3z"/>' +
        '<polygon points="15,9 21,12 15,15"/></svg>';

      // ── persisted position ────────────────────────────────────────────────
      var SIZE = 44;
      var pos = (function () {
        try {
          var p = JSON.parse(localStorage.getItem('__vt_fab_pos') || 'null');
          if (p && typeof p.x === 'number' && typeof p.y === 'number') return p;
        } catch (e) {}
        return { x: window.innerWidth - SIZE - 12, y: window.innerHeight - SIZE - 100 };
      }());

      function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
      function savePos() {
        try { localStorage.setItem('__vt_fab_pos', JSON.stringify(pos)); } catch (e) {}
      }

      // ── state ─────────────────────────────────────────────────────────────
      var drag   = { on: false, moved: false, sx: 0, sy: 0, bx: 0, by: 0 };
      var lpTimer  = null;
      var menuVisible = false;

      // ── YouTube helpers ───────────────────────────────────────────────────
      function hasVideo() {
        var v = document.querySelector('video');
        return !!(v && v.readyState > 0 && isFinite(v.duration) && v.duration > 0);
      }
      function getList() {
        try { return new URLSearchParams(location.search).get('list'); } catch (e) { return null; }
      }
      function isPanelVisible() {
        var p = document.querySelector('ytm-playlist-panel-renderer');
        if (!p) return false;
        var s = window.getComputedStyle(p);
        return s.display !== 'none' && s.visibility !== 'hidden' && p.offsetParent !== null;
      }
      function togglePiP() {
        var v = document.querySelector('video');
        if (v && typeof v.webkitSetPresentationMode === 'function') {
          v.webkitSetPresentationMode(
            v.webkitPresentationMode === 'picture-in-picture' ? 'inline' : 'picture-in-picture');
        }
      }
      function reopenPlaylist() {
        var btn = document.querySelector(
          '.ytp-playlist-menu-button, button[aria-label*="playlist" i], ' +
          'button[aria-label*="queue" i], button[aria-label*="danh sách" i]');
        if (btn) { btn.click(); return; }
        var panel = document.querySelector('ytm-playlist-panel-renderer');
        if (panel) {
          panel.style.display = '';
          panel.style.visibility = '';
          panel.removeAttribute('hidden');
          panel.removeAttribute('collapsed');
        }
      }

      // ── popup menu ────────────────────────────────────────────────────────
      function closeMenu() {
        var m = document.getElementById(MENU_ID);
        if (m) m.remove();
        menuVisible = false;
      }

      function openMenu() {
        closeMenu();
        menuVisible = true;

        var items = [
          { icon: ICON_PIP, label: 'Picture in Picture', fn: function () { closeMenu(); togglePiP(); } }
        ];
        if (/\\/watch/.test(location.pathname) && getList() && !isPanelVisible()) {
          items.push({ icon: ICON_PL, label: 'Mở playlist', fn: function () { closeMenu(); reopenPlaylist(); } });
        }

        var m = document.createElement('div');
        m.id = MENU_ID;

        var btnSz = 44;
        var gap   = 8;
        var menuW = btnSz + gap * 2;
        var menuH = items.length * btnSz + (items.length + 1) * gap;
        var mx = clamp(pos.x - (menuW - SIZE) / 2, 8, window.innerWidth  - menuW - 8);
        var my = pos.y - menuH - 8 >= 8
          ? pos.y - menuH - 8          // above
          : pos.y + SIZE + 8;          // below

        m.style.cssText =
          'position:fixed;z-index:2147483646;' +
          'left:' + mx + 'px;top:' + my + 'px;' +
          'display:flex;flex-direction:column;gap:' + gap + 'px;padding:' + gap + 'px;' +
          'background:rgba(18,18,18,0.88);border-radius:26px;' +
          'backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);' +
          'box-shadow:0 4px 20px rgba(0,0,0,0.5);';

        items.forEach(function (item) {
          var b = document.createElement('button');
          b.innerHTML = item.icon;
          b.setAttribute('aria-label', item.label);
          b.style.cssText =
            'width:' + btnSz + 'px;height:' + btnSz + 'px;' +
            'border-radius:22px;border:none;flex-shrink:0;' +
            'background:rgba(255,255,255,0.14);color:#fff;' +
            'display:flex;align-items:center;justify-content:center;' +
            'padding:0;cursor:pointer;-webkit-tap-highlight-color:transparent;';
          b.addEventListener('touchend', function (e) {
            e.stopPropagation();
            e.preventDefault();
            item.fn();
          }, true);
          m.appendChild(b);
        });

        document.body.appendChild(m);
        setTimeout(closeMenu, 3000);
      }

      // Close menu on tap anywhere outside it
      document.addEventListener('touchstart', function (e) {
        if (!menuVisible) return;
        var m = document.getElementById(MENU_ID);
        if (m && !m.contains(e.target) && e.target.id !== FAB_ID) closeMenu();
      }, true);

      // ── FAB positioning ───────────────────────────────────────────────────
      function applyPos(b) {
        b.style.left = clamp(pos.x, 8, window.innerWidth  - SIZE - 8) + 'px';
        b.style.top  = clamp(pos.y, 8, window.innerHeight - SIZE - 8) + 'px';
      }

      function snapToEdge(b) {
        var mid = window.innerWidth / 2;
        pos.x = (pos.x + SIZE / 2 < mid) ? 8 : window.innerWidth - SIZE - 8;
        pos.y = clamp(pos.y, 8, window.innerHeight - SIZE - 8);
        b.style.transition = 'left 0.2s ease, top 0.2s ease';
        applyPos(b);
        setTimeout(function () { b.style.transition = ''; }, 220);
        savePos();
      }

      // ── create FAB ────────────────────────────────────────────────────────
      function ensureFAB() {
        var b = document.getElementById(FAB_ID);
        if (b) return b;
        if (!document.body) return null;

        b = document.createElement('button');
        b.id = FAB_ID;
        b.setAttribute('aria-label', 'ViewTube controls');
        b.innerHTML = ICON_PIP;
        b.style.cssText =
          'position:fixed;z-index:2147483647;' +
          'width:' + SIZE + 'px;height:' + SIZE + 'px;' +
          'border-radius:22px;border:none;display:none;' +
          'background:rgba(0,0,0,0.55);color:#fff;' +
          'align-items:center;justify-content:center;padding:0;cursor:pointer;' +
          '-webkit-tap-highlight-color:transparent;touch-action:none;';

        applyPos(b);

        // touchstart
        b.addEventListener('touchstart', function (e) {
          e.preventDefault();
          closeMenu();
          var t = e.touches[0];
          drag.on = true; drag.moved = false;
          drag.sx = t.clientX; drag.sy = t.clientY;
          drag.bx = pos.x;    drag.by = pos.y;
          lpTimer = setTimeout(function () { if (!drag.moved) openMenu(); }, 500);
        }, { passive: false });

        // touchmove
        b.addEventListener('touchmove', function (e) {
          if (!drag.on) return;
          e.preventDefault();
          var t = e.touches[0];
          var dx = t.clientX - drag.sx;
          var dy = t.clientY - drag.sy;
          if (!drag.moved && (Math.abs(dx) > 5 || Math.abs(dy) > 5)) {
            drag.moved = true;
            clearTimeout(lpTimer);
          }
          if (drag.moved) {
            pos.x = drag.bx + dx;
            pos.y = drag.by + dy;
            applyPos(b);
          }
        }, { passive: false });

        // touchend
        b.addEventListener('touchend', function (e) {
          clearTimeout(lpTimer);
          var wasDrag = drag.moved;
          drag.on = false; drag.moved = false;
          if (wasDrag) {
            snapToEdge(b);
          } else if (!menuVisible) {
            togglePiP();
          }
        }, { passive: false });

        document.body.appendChild(b);
        return b;
      }

      // ── tick ──────────────────────────────────────────────────────────────
      function tick() {
        var b = ensureFAB();
        if (!b) return;
        b.style.display = hasVideo() ? 'flex' : 'none';
      }

      setInterval(tick, 800);
      tick();
    })();
    """

    static func floatingMenuScript() -> WKUserScript {
        WKUserScript(source: floatingMenuJS,
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

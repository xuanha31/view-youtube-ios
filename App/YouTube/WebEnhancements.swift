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

    // MARK: - Picture-in-Picture

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
}

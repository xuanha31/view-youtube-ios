import WebKit

/// Blocks YouTube ads inside the app's own WKWebView using two layers:
///  1. `WKContentRuleList` — drops network requests to known ad hosts.
///  2. `WKUserScript` — removes ad DOM nodes and auto-skips video ads.
///
/// YouTube changes its markup often; the DOM selectors in `domAdRemovalJS`
/// are the part most likely to need maintenance (see docs T1.10).
enum AdBlocker {

    // MARK: - Layer 1: network request blocking

    /// Content-blocker rules. `url-filter` is a regex matched against the URL.
    /// Kept conservative on purpose: blocking googlevideo.com would also break
    /// real video, so we only target ad/track hosts.
    static let contentRuleListJSON = """
    [
      { "trigger": { "url-filter": ".*doubleclick\\\\.net.*" },        "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*googleadservices\\\\.com.*" },   "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*googlesyndication\\\\.com.*" },  "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*google-analytics\\\\.com.*" },   "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*/pagead/.*" },                   "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*/api/stats/ads.*" },             "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*/youtubei/v1/log_event.*" },     "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*/ptracking.*" },                 "action": { "type": "block" } }
    ]
    """

    private static let ruleListIdentifier = "viewtube-adblock-rules"

    /// Compiles (or fetches the cached) content rule list. Async because
    /// WebKit compiles the JSON on a background queue.
    static func contentRuleList() async -> WKContentRuleList? {
        let store = WKContentRuleListStore.default()
        return await withCheckedContinuation { continuation in
            store?.compileContentRuleList(
                forIdentifier: ruleListIdentifier,
                encodedContentRuleList: contentRuleListJSON
            ) { list, error in
                if let error { print("[AdBlocker] rule compile failed: \(error)") }
                continuation.resume(returning: list)
            }
        }
    }

    // MARK: - Layer 2: DOM cleanup + auto-skip

    /// Runs every 400ms inside the page: removes ad containers and clicks the
    /// "Skip Ad" button. The `.ad-showing` fast-forward is a fallback for ads
    /// without a skip button.
    static let domAdRemovalJS = """
    (function () {
      'use strict';
      const AD_SELECTORS = [
        '.ytp-ad-module',
        '.video-ads',
        'ytd-ad-slot-renderer',
        'ytd-in-feed-ad-layout-renderer',
        'ytd-promoted-video-renderer',
        'ytm-promoted-video-renderer',
        'ytm-companion-ad-renderer',
        '#masthead-ad',
        '.ytp-ad-overlay-container'
      ];
      function clean() {
        AD_SELECTORS.forEach(function (sel) {
          document.querySelectorAll(sel).forEach(function (n) { n.remove(); });
        });
        const skip = document.querySelector(
          '.ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern'
        );
        if (skip) skip.click();
        const player = document.querySelector('.html5-video-player');
        const video = document.querySelector('video');
        if (player && player.classList.contains('ad-showing') && video && video.duration) {
          video.currentTime = video.duration; // fast-forward unskippable ad
        }
      }
      clean();
      setInterval(clean, 400);
    })();
    """

    static func makeUserScript() -> WKUserScript {
        WKUserScript(
            source: domAdRemovalJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
}

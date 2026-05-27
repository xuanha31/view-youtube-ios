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
    /// real video, so we only target third-party ad hosts.
    ///
    /// IMPORTANT: we intentionally do NOT block YouTube's own endpoints
    /// (/youtubei/, /api/stats, /ptracking). Blocking those trips YouTube's
    /// anti-adblock detection, which then refuses playback with a
    /// "Playback ID" error. Ads are suppressed in the DOM instead (layer 2).
    static let contentRuleListJSON = """
    [
      { "trigger": { "url-filter": ".*doubleclick\\\\.net.*" },        "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*googleadservices\\\\.com.*" },   "action": { "type": "block" } },
      { "trigger": { "url-filter": ".*googlesyndication\\\\.com.*" },  "action": { "type": "block" } }
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

    /// Runs every 500ms inside the page: removes feed/overlay ad containers and
    /// clicks "Skip Ad" when it appears.
    ///
    /// NOTE: we deliberately do NOT remove the active player module or
    /// fast-forward the <video> while an ad is showing. Doing so used to break
    /// real playback and could be flagged by YouTube. We only click the native
    /// skip button and strip non-player ad slots.
    static let domAdRemovalJS = """
    (function () {
      'use strict';
      const AD_SELECTORS = [
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
      }
      clean();
      setInterval(clean, 500);
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

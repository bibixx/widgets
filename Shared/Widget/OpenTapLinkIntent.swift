import AppIntents
import Foundation

/// The widget's tap when its card has a link. WidgetKit won't run a bare `OpenURLIntent`
/// ("no metadata for OpenURLIntent"): a button's intent must be declared in this bundle,
/// so this one hands the URL on to it.
struct OpenTapLinkIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Card Link"
  static let isDiscoverable = false

  @Parameter(title: "Link") var url: URL

  init() {}

  init(url: URL) { self.url = url }

  func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(url))
  }
}

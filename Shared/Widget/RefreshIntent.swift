import AppIntents
import WidgetKit

/// The ↻ button on Żappka widgets: asks WidgetKit for a fresh timeline without opening the app.
struct RefreshIntent: AppIntent {
  static let title: LocalizedStringResource = "Refresh card"
  static let isDiscoverable = false

  init() {}

  func perform() async throws -> some IntentResult {
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetReloader.kind)
    return .result()
  }
}

import Foundation
import WidgetKit

/// The app calls this after saving, deleting or reordering cards. Debounced, so a burst
/// of changes reloads the widgets once.
@MainActor
enum WidgetReloader {
  static let kind = "CardWidget"
  private static var pending: Task<Void, Never>?

  static func reloadAll() {
    pending?.cancel()
    pending = Task {
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      WidgetCenter.shared.reloadAllTimelines()
    }
  }
}

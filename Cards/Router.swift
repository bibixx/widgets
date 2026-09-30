import Foundation
import Observation

@MainActor
@Observable
final class Router {
  enum Editing: Identifiable {
    case new(Preset)
    case existing(UUID)
    var id: String {
      switch self {
      case .new(let preset): "new-\(preset.id)"
      case .existing(let id): id.uuidString
      }
    }
  }

  var editing: Editing?
  var choosingPreset = false

  /// `cards://card/<uuid>` → editor. The older `…/edit` form (widgets placed before the
  /// checkout view was removed) is accepted too.
  func open(_ url: URL) {
    guard url.scheme == "cards", url.host() == "card" else { return }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard let first = parts.first, let id = UUID(uuidString: first) else { return }
    choosingPreset = false
    editing = .existing(id)
  }

  static func url(for cardID: UUID) -> URL { DeepLink.card(cardID) }
}

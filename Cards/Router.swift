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

  /// The card shown in the fullscreen checkout view.
  var checkoutCardID: UUID?
  var editing: Editing?
  var choosingPreset = false

  /// `cards://card/<uuid>` → checkout, `cards://card/<uuid>/edit` → editor.
  func open(_ url: URL) {
    guard url.scheme == "cards", url.host() == "card" else { return }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard let first = parts.first, let id = UUID(uuidString: first) else { return }
    editing = nil
    choosingPreset = false
    if parts.dropFirst().first == "edit" {
      checkoutCardID = nil
      editing = .existing(id)
    } else {
      checkoutCardID = id
    }
  }

  static func url(for cardID: UUID, edit: Bool = false) -> URL { DeepLink.card(cardID, edit: edit) }
}

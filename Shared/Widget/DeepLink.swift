import Foundation

/// `cards://card/<uuid>` opens the checkout view; `…/edit` opens the editor.
enum DeepLink {
  static func card(_ id: UUID, edit: Bool = false) -> URL {
    URL(string: "cards://card/\(id.uuidString)\(edit ? "/edit" : "")")!
  }
}

import Foundation

/// `cards://card/<uuid>` opens the card's editor.
enum DeepLink {
  static func card(_ id: UUID) -> URL {
    URL(string: "cards://card/\(id.uuidString)")!
  }
}

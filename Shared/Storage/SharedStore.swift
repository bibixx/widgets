import Foundation
import SwiftData

enum SharedStore {
  static let appGroup = "group.io.legiec.cards"

  /// The app and the widget open the same SQLite file in the App Group container.
  /// The widget only fetches, never writes.
  static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
    let schema = Schema(versionedSchema: CardsSchemaV1.self)
    let configuration = inMemory
      ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
      : ModelConfiguration(schema: schema, url: try storeURL())
    return try ModelContainer(for: schema, migrationPlan: CardsMigrationPlan.self, configurations: [configuration])
  }

  /// `<App Group>/Library/Application Support/Cards.store`; the folder is created on first use
  /// (Core Data won't create it inside a fresh group container).
  static func storeURL() throws -> URL {
    let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
      ?? URL.applicationSupportDirectory
    let directory = base.appending(path: "Library/Application Support", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "Cards.store")
  }

  static func fetchCards(in context: ModelContext) throws -> [Card] {
    try context.fetch(FetchDescriptor<Card>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]))
  }

  static func fetchCard(id: UUID, in context: ModelContext) throws -> Card? {
    var descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }
}

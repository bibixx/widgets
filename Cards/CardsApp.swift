import SwiftData
import SwiftUI

@main
struct CardsApp: App {
  @State private var router = Router()
  private let container: ModelContainer

  init() {
    do {
      container = try SharedStore.makeContainer()
    } catch {
      // The App Group store should always open; fall back so the app still runs.
      container = try! SharedStore.makeContainer(inMemory: true)
    }
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-seed-samples") { Self.seedSamples(into: container) }
    #endif
  }

  #if DEBUG
  /// Debug only: fills an empty store with the made-up preview cards (fake Żappka secret).
  @MainActor private static func seedSamples(into container: ModelContainer) {
    let context = container.mainContext
    guard (try? context.fetchCount(FetchDescriptor<Card>())) == 0 else { return }
    for (index, sample) in CardPreviewFixtures.all.enumerated() {
      let card = Card(
        name: sample.name, presetID: sample.presetID, symbology: sample.symbology, content: sample.content,
        color1Hex: sample.color1Hex, color2Hex: sample.color2Hex, logo: sample.logo, sortIndex: index)
      context.insert(card)
      if let secret = sample.zappkaSecret { try? SecretStore().setZappkaSecret(secret, for: card.id) }
    }
    try? context.save()
  }
  #endif

  var body: some Scene {
    WindowGroup {
      CardListView()
        .environment(router)
        .onOpenURL { router.open($0) }
        .task {
          WidgetReloader.reloadAll()
          #if DEBUG
          // Debug: `-open cards://card/<id>/edit` routes like a tapped widget, without the system prompt.
          let args = ProcessInfo.processInfo.arguments
          if let i = args.firstIndex(of: "-open"), i + 1 < args.count, let url = URL(string: args[i + 1]) {
            router.open(url)
          }
          #endif
        }
    }
    .modelContainer(container)
  }
}

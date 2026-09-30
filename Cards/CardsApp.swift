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
  }

  var body: some Scene {
    WindowGroup {
      CardListView()
        .environment(router)
        .onOpenURL { router.open($0) }
        .task { WidgetReloader.reloadAll() }
    }
    .modelContainer(container)
  }
}

import SwiftData
import SwiftUI

struct CardListView: View {
  @Environment(Router.self) private var router
  @Environment(\.modelContext) private var context
  @Query(sort: [SortDescriptor(\Card.sortIndex), SortDescriptor(\Card.createdAt)]) private var cards: [Card]
  @State private var pendingDelete: Card?

  var body: some View {
    @Bindable var router = router
    NavigationStack {
      Group {
        if cards.isEmpty {
          EmptyCardsView { router.editing = .new($0) }
        } else {
          list
        }
      }
      .navigationTitle("Cards")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add card", systemImage: "plus") { router.choosingPreset = true }
        }
        if !cards.isEmpty {
          ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
      }
    }
    .sheet(isPresented: $router.choosingPreset) {
      PresetChooser { preset in
        router.choosingPreset = false
        router.editing = .new(preset)
      }
      .presentationDetents([.medium])
    }
    .sheet(item: $router.editing) { editing in
      editor(for: editing)
    }
    .fullScreenCover(isPresented: checkoutBinding) {
      CardFullscreenView(cards: cards, selection: $router.checkoutCardID)
    }
    .confirmationDialog(
      "Delete \(pendingDelete?.name ?? "card")?", isPresented: deleteBinding, titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        if let card = pendingDelete { try? Card.delete(card, in: context) }
        pendingDelete = nil
      }
    } message: {
      Text("Widgets showing this card will ask you to pick another one.")
    }
  }

  private var list: some View {
    List {
      ForEach(cards) { card in
        Button {
          router.checkoutCardID = card.id
        } label: {
          CardRow(card: card)
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) {
          Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = card }
          Button("Edit", systemImage: "pencil") { router.editing = .existing(card.id) }
            .tint(.blue)
        }
        .contextMenu {
          Button("Edit", systemImage: "pencil") { router.editing = .existing(card.id) }
          Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = card }
        }
      }
      .onMove(perform: move)
    }
  }

  @ViewBuilder
  private func editor(for editing: Router.Editing) -> some View {
    switch editing {
    case .new(let preset):
      CardEditorView(draft: EditorDraft(preset: preset))
    case .existing(let id):
      if let card = cards.first(where: { $0.id == id }) {
        CardEditorView(draft: EditorDraft(card: card, secret: try? SecretStore().zappkaSecret(for: id)))
      } else {
        ContentUnavailableView("Card not found", systemImage: "questionmark.square.dashed")
      }
    }
  }

  private func move(from source: IndexSet, to destination: Int) {
    var reordered = cards
    reordered.move(fromOffsets: source, toOffset: destination)
    for (index, card) in reordered.enumerated() where card.sortIndex != index {
      card.sortIndex = index
    }
    try? context.save()
    WidgetReloader.reloadAll()
  }

  private var checkoutBinding: Binding<Bool> {
    Binding(get: { router.checkoutCardID != nil }, set: { if !$0 { router.checkoutCardID = nil } })
  }

  private var deleteBinding: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }
}

struct EmptyCardsView: View {
  let onPick: (Preset) -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        ContentUnavailableView(
          "Add your first card", systemImage: "creditcard",
          description: Text("Pick a store to start. You can change everything in the editor."))
        PresetGrid(onPick: onPick)
      }
      .padding()
    }
  }
}

struct PresetChooser: View {
  let onPick: (Preset) -> Void

  var body: some View {
    NavigationStack {
      ScrollView { PresetGrid(onPick: onPick).padding() }
        .navigationTitle("Add card")
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}

struct PresetGrid: View {
  let onPick: (Preset) -> Void

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
      ForEach(Presets.all) { preset in
        Button {
          onPick(preset)
        } label: {
          VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
              LinearGradient(
                colors: [Color(hex: preset.color1Hex), Color(hex: preset.color2Hex)], startPoint: .top, endPoint: .bottom)
              if let logo = preset.logoName {
                Image(logo).resizable().scaledToFit().frame(height: 22).padding(.horizontal, 12)
              }
            }
            .frame(height: 44)
            Text(preset.name)
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.primary)
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .background(Color(.secondarySystemGroupedBackground))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }
}

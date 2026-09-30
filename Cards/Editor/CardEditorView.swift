import SwiftData
import SwiftUI

struct CardEditorView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State var draft: EditorDraft
  @State private var saveError: String?
  @State private var importer = CodeImporter()
  @State private var dropTargeted = false

  var body: some View {
    NavigationStack {
      Form {
        PresetSection(draft: draft)
        Section("Name") {
          TextField(draft.preset?.name ?? "Card name", text: $draft.name)
            .textInputAutocapitalization(.words)
        }
        ContentSection(draft: draft, importer: importer)
        CodeTypeSection(draft: draft)
        StyleSection(draft: draft)
        LogoSection(draft: draft)
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        LivePreviewPanel(draft: draft)
      }
      // Drop a screenshot (drag its thumbnail) or any image anywhere to read its code.
      .dropDestination(for: DroppedImage.self) { images, _ in
        guard let image = images.first else { return false }
        Task { await importer.importImage(image.data, into: draft) }
        return true
      } isTargeted: { dropTargeted = $0 }
      .overlay {
        if dropTargeted {
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
              Label(draft.contentKind == .zappka ? "Drop to read the Żappka code" : "Drop to read the code", systemImage: "barcode.viewfinder")
                .font(.headline)
                .padding(12)
                .background(.regularMaterial, in: Capsule())
            }
            .padding(8)
            .allowsHitTesting(false)
        }
      }
      .codeImportDialogs(importer, draft: draft)
      .navigationTitle(draft.isNew ? "New Card" : "Edit Card")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
            .disabled(!draft.canSave)
        }
      }
      .alert("Couldn't save", isPresented: .constant(saveError != nil)) {
        Button("OK") { saveError = nil }
      } message: {
        Text(saveError ?? "")
      }
    }
    .interactiveDismissDisabled()
  }

  private func save() {
    do {
      try draft.save(in: context)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      dismiss()
    } catch {
      saveError = error.localizedDescription
    }
  }
}

/// Shows a validation message under a field.
struct FieldMessage: View {
  let text: String
  var isError: Bool

  var body: some View {
    Label(text, systemImage: isError ? "xmark.octagon.fill" : "info.circle")
      .font(.footnote)
      .foregroundStyle(isError ? .red : .secondary)
  }
}

struct PresetLogoThumb: View {
  let preset: Preset

  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(hex: preset.color1Hex), Color(hex: preset.color2Hex)], startPoint: .top, endPoint: .bottom)
      if let name = preset.logoName {
        Image(name).resizable().scaledToFit().padding(6)
      } else {
        Image(systemName: "creditcard").foregroundStyle(.white)
      }
    }
    .frame(width: 52, height: 30)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

struct ScrollEdgeFades: ViewModifier {
  var width: CGFloat = 24

  @State private var fadesLeading = false
  @State private var fadesTrailing = false

  private struct HiddenEdges: Equatable {
    var leading: Bool
    var trailing: Bool
  }

  func body(content: Content) -> some View {
    content
      .onScrollGeometryChange(for: HiddenEdges.self) { geometry in
        let visible = geometry.visibleRect
        return HiddenEdges(
          leading: visible.minX > 1,
          trailing: visible.maxX < geometry.contentSize.width - 1
        )
      } action: { _, edges in
        withAnimation(.easeOut(duration: 0.2)) {
          fadesLeading = edges.leading
          fadesTrailing = edges.trailing
        }
      }
      .mask {
        HStack(spacing: 0) {
          edge(fading: fadesLeading, from: .leading)
          Rectangle()
          edge(fading: fadesTrailing, from: .trailing)
        }
      }
  }

  private func edge(fading: Bool, from start: UnitPoint) -> some View {
    LinearGradient(
      colors: [.black.opacity(fading ? 0 : 1), .black],
      startPoint: start,
      endPoint: start == .leading ? .trailing : .leading
    )
    .frame(width: width)
  }
}

extension View {
  /// Fades the edges of a horizontal scroll view where content is scrolled out of sight.
  func scrollEdgeFades() -> some View {
    modifier(ScrollEdgeFades())
  }
}

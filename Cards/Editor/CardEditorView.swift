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
    // Drop a screenshot (drag its thumbnail) or any image anywhere on the sheet to read its code.
    .background(EditorDropCatcher(isTargeted: $dropTargeted) { data in
      Task { await importer.importImage(data, into: draft) }
    })
    .overlay {
      if dropTargeted {
        // Down to the screen's bottom edge (the drop works there too); bottom corners follow
        // the display's rounded corners.
        let outline = UnevenRoundedRectangle(
          topLeadingRadius: 24, bottomLeadingRadius: 44, bottomTrailingRadius: 44, topTrailingRadius: 24,
          style: .continuous)
        outline
          .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
          .background(Color.accentColor.opacity(0.08), in: outline)
          .overlay {
            Label(draft.contentKind == .zappka ? "Drop to read the Żappka code" : "Drop to read the code", systemImage: "barcode.viewfinder")
              .font(.headline)
              .padding(12)
              .background(.regularMaterial, in: Capsule())
          }
          .padding(8)
          .ignoresSafeArea(.all, edges: .bottom)
          .allowsHitTesting(false)
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

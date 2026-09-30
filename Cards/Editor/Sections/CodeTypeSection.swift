import SwiftUI

/// Hidden for Żappka, whose code types are fixed (PDF417 horizontal, QR square).
struct CodeTypeSection: View {
  @Bindable var draft: EditorDraft

  var body: some View {
    if draft.contentKind == .raw {
      Section("Code") {
        picker("Horizontal", selection: $draft.symbology)
        picker("Square", selection: $draft.squareSymbology)
        if draft.symbology.kind == .linear || draft.squareSymbology.kind == .linear {
          Toggle("Show number under code", isOn: $draft.showsCaption)
        }
      }
    }
  }

  /// A menu of toggles rather than a Picker: Picker ignores `.disabled` on its options.
  private func picker(_ title: String, selection: Binding<Symbology>) -> some View {
    LabeledContent(title) {
      Menu {
        Section("Linear") { options(.linear, selection: selection) }
        Section("Stacked") { options(.stacked, selection: selection) }
        Section("2D") { options(.twoD, selection: selection) }
      } label: {
        HStack(spacing: 4) {
          Text(selection.wrappedValue.displayName)
          Image(systemName: "chevron.up.chevron.down").imageScale(.small)
        }
      }
      .tint(.secondary)
    }
  }

  /// Types that can't encode the typed number are disabled (the current one stays
  /// enabled so it still shows as selected).
  private func options(_ kind: Symbology.Kind, selection: Binding<Symbology>) -> some View {
    ForEach(Symbology.allCases.filter { $0.kind == kind }) { type in
      Toggle(type.displayName, isOn: Binding(
        get: { selection.wrappedValue == type },
        set: { if $0 { selection.wrappedValue = type } }))
        .disabled(type != selection.wrappedValue && !canEncode(type))
    }
  }

  private func canEncode(_ type: Symbology) -> Bool {
    draft.rawData.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !BarcodeValidation.validate(draft.rawData, for: type).isError
  }
}

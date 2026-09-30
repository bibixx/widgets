import SwiftUI

struct StyleSection: View {
  @Bindable var draft: EditorDraft

  var body: some View {
    Section("Colours") {
      ColorPicker("From (top)", selection: hexBinding(\.color1Hex), supportsOpacity: false)
      ColorPicker("To (bottom)", selection: hexBinding(\.color2Hex), supportsOpacity: false)
      HStack {
        Button("Swap", systemImage: "arrow.up.arrow.down") { draft.swapColors() }
        Spacer()
        if draft.preset != nil {
          Button("Reset to preset", systemImage: "arrow.counterclockwise") { draft.resetColorsToPreset() }
        }
      }
      .buttonStyle(.borderless)
    }
  }

  private func hexBinding(_ keyPath: ReferenceWritableKeyPath<EditorDraft, String>) -> Binding<Color> {
    Binding(
      get: { Color(hex: draft[keyPath: keyPath]) },
      set: { draft[keyPath: keyPath] = $0.hexString })
  }
}

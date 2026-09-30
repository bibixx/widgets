import SwiftUI

struct PresetSection: View {
  @Bindable var draft: EditorDraft

  var body: some View {
    Section {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(Presets.all) { preset in
            Button {
              withAnimation(.snappy) { draft.apply(preset) }
            } label: {
              VStack(spacing: 4) {
                PresetLogoThumb(preset: preset)
                  .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                      .strokeBorder(draft.presetID == preset.id ? Color.accentColor : .clear, lineWidth: 2.5)
                  }
                Text(preset.name).font(.caption2).foregroundStyle(.primary)
              }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(draft.presetID == preset.id ? .isSelected : [])
          }
        }
        .padding(.vertical, 4)
      }
    } header: {
      Text("Preset")
    } footer: {
      Text("Sets colours, logo and code type. Your card number is kept.")
    }
  }
}

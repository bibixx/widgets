import SwiftUI

struct CodeTypeSection: View {
  @Bindable var draft: EditorDraft

  var body: some View {
    Section {
      if draft.contentKind == .zappka {
        LabeledContent("Code type", value: Zappka.symbology.displayName)
      } else {
        Picker("Code type", selection: $draft.symbology) {
          Section("Linear") { ForEach(Symbology.allCases.filter { $0.kind == .linear }) { Text($0.displayName).tag($0) } }
          Section("Stacked") { ForEach(Symbology.allCases.filter { $0.kind == .stacked }) { Text($0.displayName).tag($0) } }
          Section("2D") { ForEach(Symbology.allCases.filter { $0.kind == .twoD }) { Text($0.displayName).tag($0) } }
        }
        if draft.symbology.kind == .linear {
          Toggle("Show number under code", isOn: $draft.showsCaption)
        }
      }
    } header: {
      Text("Code")
    } footer: {
      if draft.contentKind == .zappka {
        Text("Żabka's scanners read the rotating code as PDF417.")
      }
    }
  }
}

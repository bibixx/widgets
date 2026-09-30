import SwiftUI

/// What tapping the widget opens: another app's deep link or a web page.
struct TapSection: View {
  @Bindable var draft: EditorDraft
  @Environment(\.openURL) private var openURL

  var body: some View {
    Section {
      HStack {
        TextField("zappka://, https://…", text: $draft.tapURL)
          .keyboardType(.URL)
          .textContentType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        if case .url(let url) = draft.tapLink {
          Button("Try", systemImage: "arrow.up.forward.app") { openURL(url) }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
      }
      if draft.tapLink == .invalid {
        FieldMessage(text: "Not a link", isError: true)
      }
    } header: {
      Text("Widget tap")
    } footer: {
      Text("Tapping the widget opens this link, e.g. the store's app. Leave empty to open the card here.")
    }
  }
}

import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// Reads barcodes out of an image (a picked photo or a dropped screenshot) and fills the
/// draft: the card number (and code type), or the User ID for a Żappka card.
@MainActor
@Observable
final class CodeImporter {
  /// Several codes in one image: the editor asks which one.
  var choices: [BarcodeDecoder.Detected] = []
  /// Shown when nothing usable was found.
  var failure: String?

  func importImage(_ data: Data, into draft: EditorDraft) async {
    let codes = await Task.detached { UIImage(data: data)?.cgImage.map(BarcodeDecoder.detect(in:)) ?? [] }.value
    if draft.contentKind == .zappka {
      guard let userId = codes.lazy.compactMap({ Zappka.userId(fromPayload: $0.text) }).first else {
        failure = codes.isEmpty ? Self.noCode : "That code isn't a Żappka code."
        return
      }
      draft.zappkaUserId = userId
      return
    }
    switch codes.count {
    case 0: failure = Self.noCode
    case 1: draft.importCode(codes[0])
    default: choices = codes
    }
  }

  private static let noCode = "No barcode found. Try an image where the whole code is visible."
}

extension View {
  /// The "which code?" and "nothing found" dialogs for a `CodeImporter`.
  func codeImportDialogs(_ importer: CodeImporter, draft: EditorDraft) -> some View {
    modifier(CodeImportDialogs(importer: importer, draft: draft))
  }
}

private struct CodeImportDialogs: ViewModifier {
  @Bindable var importer: CodeImporter
  let draft: EditorDraft

  func body(content: Content) -> some View {
    content
      .confirmationDialog("Which code?", isPresented: choosing, titleVisibility: .visible) {
        ForEach(importer.choices, id: \.self) { code in
          Button(label(for: code)) { draft.importCode(code) }
        }
      }
      .alert("Couldn't read a code", isPresented: failing) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(importer.failure ?? "")
      }
  }

  private var choosing: Binding<Bool> {
    Binding(get: { !importer.choices.isEmpty }, set: { if !$0 { importer.choices = [] } })
  }

  private var failing: Binding<Bool> {
    Binding(get: { importer.failure != nil }, set: { if !$0 { importer.failure = nil } })
  }

  private func label(for code: BarcodeDecoder.Detected) -> String {
    let text = code.text.count > 24 ? String(code.text.prefix(24)) + "…" : code.text
    return "\(code.symbology?.displayName ?? "Barcode") · \(text)"
  }
}

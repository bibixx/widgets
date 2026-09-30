import SwiftUI
import VisionKit

struct ContentSection: View {
  @Bindable var draft: EditorDraft
  @State private var revealsSecret = false
  @State private var scanning = false

  var body: some View {
    Section {
      switch draft.contentKind {
      case .raw: raw
      case .zappka: zappka
      }
    } header: {
      Text(draft.contentKind == .zappka ? "Żappka account" : "Card number")
    }
  }

  @ViewBuilder private var raw: some View {
    HStack {
      TextField(draft.symbology.placeholder, text: $draft.rawData)
        .keyboardType(draft.symbology.keyboard == .numberPad ? .numberPad : .asciiCapable)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(.body.monospaced())
      if DataScannerViewController.isSupported {
        Button {
          scanning = true
        } label: {
          Image(systemName: "barcode.viewfinder")
        }
        .accessibilityLabel("Scan a card")
        .sheet(isPresented: $scanning) {
          BarcodeScannerSheet { value in
            draft.rawData = value
            scanning = false
          }
        }
      }
    }
    if !draft.rawData.isEmpty, let message = draft.rawValidation.message {
      FieldMessage(text: message, isError: draft.rawValidation.isError)
    }
  }

  @ViewBuilder private var zappka: some View {
    TextField("User ID", text: $draft.zappkaUserId)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .font(.body.monospaced())
    HStack {
      Group {
        if revealsSecret {
          TextField("Secret", text: $draft.zappkaSecret)
        } else {
          SecureField("Secret", text: $draft.zappkaSecret)
        }
      }
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .font(.body.monospaced())
      Button {
        revealsSecret.toggle()
      } label: {
        Image(systemName: revealsSecret ? "eye.slash" : "eye")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(revealsSecret ? "Hide secret" : "Show secret")
    }
    ForEach(visibleIssues, id: \.self) { issue in
      FieldMessage(text: issue.message, isError: issue.isError)
    }
  }

  /// Don't nag about empty fields before anything is typed.
  private var visibleIssues: [ZappkaCredentials.Issue] {
    draft.credentialIssues.filter { issue in
      switch issue {
      case .missingUserId: !draft.zappkaSecret.isEmpty
      case .missingSecret: !draft.zappkaUserId.isEmpty
      default: true
      }
    }
  }
}

/// VisionKit's live scanner, returning the first barcode it recognises.
struct BarcodeScannerSheet: UIViewControllerRepresentable {
  let onScan: (String) -> Void

  func makeUIViewController(context: Context) -> DataScannerViewController {
    let controller = DataScannerViewController(
      recognizedDataTypes: [.barcode()], qualityLevel: .accurate, isHighlightingEnabled: true)
    controller.delegate = context.coordinator
    try? controller.startScanning()
    return controller
  }

  func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    let onScan: (String) -> Void
    init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
      for item in addedItems {
        if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
          dataScanner.stopScanning()
          onScan(value)
          return
        }
      }
    }
  }
}

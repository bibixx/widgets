import SwiftUI
import VisionKit

struct ContentSection: View {
  @Bindable var draft: EditorDraft
  @State private var revealsSecret = false
  @State private var scanning = false

  var body: some View {
    Section {
      Picker("Content", selection: Binding(get: { draft.contentKind }, set: { draft.setContentKind($0) })) {
        Text("Card number").tag(CardContent.Kind.raw)
        Text("Żappka (rotating)").tag(CardContent.Kind.zappka)
      }
      .pickerStyle(.segmented)

      switch draft.contentKind {
      case .raw: raw
      case .zappka: zappka
      }
    } header: {
      Text("Content")
    } footer: {
      if draft.contentKind == .zappka {
        Text("Stored in the Keychain on this device only.")
      }
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
    HStack {
      TextField("User ID", text: $draft.zappkaUserId)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(.body.monospaced())
      PasteButton(payloadType: String.self) { strings in
        guard let value = strings.first else { return }
        Task { @MainActor in draft.zappkaUserId = value.trimmingCharacters(in: .whitespacesAndNewlines) }
      }
      .labelStyle(.iconOnly)
      .buttonBorderShape(.circle)
    }
    HStack {
      Group {
        if revealsSecret {
          TextField("Secret (hex)", text: $draft.zappkaSecret)
        } else {
          SecureField("Secret (hex)", text: $draft.zappkaSecret)
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
      PasteButton(payloadType: String.self) { strings in
        guard let value = strings.first else { return }
        Task { @MainActor in draft.zappkaSecret = ZappkaCredentials.normalizeSecret(value) }
      }
      .labelStyle(.iconOnly)
      .buttonBorderShape(.circle)
    }
    ForEach(visibleIssues, id: \.self) { issue in
      FieldMessage(text: issue.message, isError: issue.isError)
    }
    if draft.credentials.isValid {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let window = Zappka.window(containing: context.date)
        LabeledContent("Current code") {
          HStack(spacing: 8) {
            Text(Zappka.code(for: draft.credentials, at: context.date) ?? "—").font(.body.monospaced().weight(.semibold))
            Text("\(Int(window.end.timeIntervalSince(context.date).rounded(.up)))s")
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
      }
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

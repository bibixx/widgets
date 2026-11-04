import PhotosUI
import SwiftUI
import Vision
import VisionKit

struct ContentSection: View {
  @Bindable var draft: EditorDraft
  let importer: CodeImporter
  @State private var revealsSecret = false
  @State private var signingIn = false
  /// Revealed by tapping the "Żappka account" header five times in quick succession.
  @State private var showsManualEntry = false
  @State private var headerTaps: [Date] = []
  @State private var scanning = false
  @State private var pickingPhoto = false
  @State private var photo: PhotosPickerItem?

  var body: some View {
    Section {
      switch draft.contentKind {
      case .raw: raw
      case .zappka: zappka
      }
    } header: {
      if draft.contentKind == .zappka {
        Text("Żappka account")
          .contentShape(.rect)
          .onTapGesture(perform: countHeaderTap)
      } else {
        Text("Card number")
      }
    }
  }

  private func countHeaderTap() {
    let now = Date.now
    headerTaps = headerTaps.filter { now.timeIntervalSince($0) < 2 } + [now]
    guard headerTaps.count >= 5 else { return }
    headerTaps = []
    withAnimation { showsManualEntry.toggle() }
  }

  @ViewBuilder private var raw: some View {
    HStack {
      TextField(draft.symbology.placeholder, text: $draft.rawData)
        .keyboardType(draft.symbology.keyboard == .numberPad ? .numberPad : .asciiCapable)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(.body.monospaced())
      Menu {
        if DataScannerViewController.isSupported {
          Button("Scan with Camera", systemImage: "camera") { scanning = true }
        }
        Button("Choose Photo", systemImage: "photo") { pickingPhoto = true }
      } label: {
        Image(systemName: "barcode.viewfinder")
      }
      .accessibilityLabel("Import card number")
    }
    .sheet(isPresented: $scanning) {
      BarcodeScannerSheet { code in
        draft.importCode(code)
        scanning = false
      }
    }
    .photosPicker(isPresented: $pickingPhoto, selection: $photo, matching: .images)
    .onChange(of: photo) { _, item in
      guard let item else { return }
      photo = nil
      Task { await importPhoto(item) }
    }
    if !draft.rawData.isEmpty, let message = draft.rawValidation.message {
      FieldMessage(text: message, isError: draft.rawValidation.isError)
    }
  }

  @ViewBuilder private var zappka: some View {
    let userId = draft.zappkaUserId.trimmingCharacters(in: .whitespacesAndNewlines)
    if !userId.isEmpty && !draft.zappkaSecret.isEmpty {
      LabeledContent("Signed in as") {
        Text(userId).font(.body.monospaced()).lineLimit(1).truncationMode(.middle)
      }
      // Settings-style: centered red text, no icon.
      Button(role: .destructive) {
        draft.signOutOfZappka()
      } label: {
        Text("Sign Out").frame(maxWidth: .infinity)
      }
    } else {
      Button("Sign in with Żabka…", systemImage: "person.badge.key") { signingIn = true }
        .sheet(isPresented: $signingIn) {
          ZappkaLoginSheet { draft.apply($0) }
        }
    }
    if showsManualEntry {
      manualZappkaFields
    }
    ForEach(visibleIssues, id: \.self) { issue in
      FieldMessage(text: issue.message, isError: issue.isError)
    }
  }

  /// Hidden debug panel: see what sign-in fetched, or type credentials in by hand.
  @ViewBuilder private var manualZappkaFields: some View {
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
    Text("Debug: manual entry")
      .font(.footnote)
      .foregroundStyle(.secondary)
  }

  /// Don't nag about empty fields before anything is typed. Without the debug panel there are
  /// no fields to type in, so missing ones aren't shown at all (the sign-in button is the hint).
  private var visibleIssues: [ZappkaCredentials.Issue] {
    draft.credentialIssues.filter { issue in
      if !showsManualEntry, issue == .missingUserId || issue == .missingSecret { return false }
      return switch issue {
      case .missingUserId: !draft.zappkaSecret.isEmpty
      case .missingSecret: !draft.zappkaUserId.isEmpty
      default: true
      }
    }
  }

  // MARK: Photo import

  private func importPhoto(_ item: PhotosPickerItem) async {
    guard let data = try? await item.loadTransferable(type: Data.self) else {
      importer.failure = "Couldn't open that photo."
      return
    }
    await importer.importImage(data, into: draft)
  }
}

/// VisionKit's live scanner, returning the first barcode it recognises.
struct BarcodeScannerSheet: UIViewControllerRepresentable {
  let onScan: (BarcodeDecoder.Detected) -> Void

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
    let onScan: (BarcodeDecoder.Detected) -> Void
    init(onScan: @escaping (BarcodeDecoder.Detected) -> Void) { self.onScan = onScan }

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
      for item in addedItems {
        if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
          dataScanner.stopScanning()
          onScan(BarcodeDecoder.Detected(text: value, symbology: Symbology(barcode.observation.symbology)))
          return
        }
      }
    }
  }
}

private extension Symbology {
  /// Vision reports UPC-A as EAN-13 (with a leading 0), which draws the same bars.
  init?(_ vision: VNBarcodeSymbology) {
    switch vision {
    case .pdf417: self = .pdf417
    case .qr: self = .qr
    case .aztec: self = .aztec
    case .dataMatrix: self = .dataMatrix
    case .code128: self = .code128
    case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: self = .code39
    case .code93, .code93i: self = .code93
    case .ean13: self = .ean13
    case .ean8: self = .ean8
    case .upce: self = .upcE
    case .itf14, .i2of5, .i2of5Checksum: self = .itf
    case .codabar: self = .codabar
    default: return nil
    }
  }
}

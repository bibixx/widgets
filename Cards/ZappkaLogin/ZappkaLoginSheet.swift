import SwiftUI

@MainActor
@Observable
final class ZappkaLoginModel {
  enum Step: Equatable {
    case phone
    case code(ZappkaLoginClient.PendingSignIn)
  }

  var step: Step = .phone
  var phone = ""
  var code = ""
  var isWorking = false
  var error: String?
  /// When "Resend" becomes available.
  var resendAt: Date?

  private let client: ZappkaLoginClient

  init(client: ZappkaLoginClient = ZappkaLoginClient()) { self.client = client }

  var canSendCode: Bool { !isWorking && ZappkaLoginClient.normalizePhone(phone) != nil }
  var canSignIn: Bool { !isWorking && code.contains(where: \.isNumber) }

  func sendCode() async {
    await run {
      let pending = try await client.requestCode(phone: phone)
      code = ""
      step = .code(pending)
      scheduleResend(pending)
    }
  }

  func resend() async {
    guard case .code(let pending) = step else { return }
    await run {
      let next = try await client.resendCode(pending)
      step = .code(next)
      scheduleResend(next)
    }
  }

  func signIn() async -> ZappkaCredentials? {
    guard case .code(let pending) = step else { return nil }
    var result: ZappkaCredentials?
    await run { result = try await client.finish(pending, code: code) }
    return result
  }

  func changeNumber() {
    step = .phone
    code = ""
    error = nil
    resendAt = nil
  }

  private func scheduleResend(_ pending: ZappkaLoginClient.PendingSignIn) {
    resendAt = Date.now.addingTimeInterval(TimeInterval(pending.retryAfterSeconds ?? 30))
  }

  private func run(_ work: () async throws -> Void) async {
    isWorking = true
    error = nil
    defer { isWorking = false }
    do {
      try await work()
    } catch let failure as ZappkaLoginError {
      error = failure.errorDescription
    } catch {
      self.error = ZappkaLoginError.unexpectedResponse.errorDescription
    }
  }
}

/// Phone number → SMS code → credentials handed to `onSignIn`.
struct ZappkaLoginSheet: View {
  let onSignIn: (ZappkaCredentials) -> Void
  @State private var model = ZappkaLoginModel()
  @Environment(\.dismiss) private var dismiss
  private enum Field { case phone, code }
  @FocusState private var focused: Field?

  var body: some View {
    NavigationStack {
      Form {
        switch model.step {
        case .phone: phoneStep
        case .code(let pending): codeStep(pending)
        }
        if let error = model.error {
          Section { FieldMessage(text: error, isError: true) }
        }
      }
      .navigationTitle("Sign in with Żabka")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          if model.isWorking {
            ProgressView()
          } else {
            switch model.step {
            case .phone:
              Button("Send Code") { Task { await model.sendCode() } }
                .disabled(!model.canSendCode)
            case .code:
              Button("Sign In") { Task { await signIn() } }
                .disabled(!model.canSignIn)
            }
          }
        }
      }
      .onAppear { focused = .phone }
      .onChange(of: model.step) { _, step in
        // The code field only exists after this update, so focus it on the next run loop turn.
        let field: Field = if case .code = step { .code } else { .phone }
        Task { focused = field }
      }
    }
    .interactiveDismissDisabled(model.isWorking)
  }

  private var phoneStep: some View {
    Section {
      HStack {
        Text("+48").foregroundStyle(.secondary)
        TextField("Phone number", text: $model.phone)
          .keyboardType(.phonePad)
          .textContentType(.telephoneNumber)
          .focused($focused, equals: .phone)
          .onSubmit { Task { await model.sendCode() } }
      }
    } header: {
      Text("Phone number")
    } footer: {
      Text("Use the number of your Żabka account. You'll get an SMS code. Cards keeps only the secret behind your Żappka code, never your login.")
    }
  }

  private func codeStep(_ pending: ZappkaLoginClient.PendingSignIn) -> some View {
    Section {
      TextField("Code", text: $model.code)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .font(.body.monospaced())
        .focused($focused, equals: .code)
        .onSubmit { Task { await signIn() } }
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let remaining = Int(ceil((model.resendAt ?? context.date).timeIntervalSince(context.date)))
        Button(remaining > 0 ? "Resend Code (\(remaining) s)" : "Resend Code") {
          Task { await model.resend() }
        }
        .disabled(remaining > 0 || model.isWorking)
      }
      Button("Change Number") { model.changeNumber() }
        .disabled(model.isWorking)
    } header: {
      Text("SMS code")
    } footer: {
      Text("Sent to +48 \(pending.phone).")
    }
  }

  private func signIn() async {
    guard model.canSignIn, let credentials = await model.signIn() else { return }
    onSignIn(credentials)
    dismiss()
  }
}

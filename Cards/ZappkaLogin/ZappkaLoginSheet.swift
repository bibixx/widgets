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
  var canSignIn: Bool { !isWorking && code.count == Self.codeLength }

  static let codeLength = 6

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
    if result == nil { code = "" }
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

/// Phone number → SMS code → credentials and the national number handed to `onSignIn`.
struct ZappkaLoginSheet: View {
  let onSignIn: (ZappkaCredentials, _ phone: String) -> Void
  @State private var model = ZappkaLoginModel()
  @Environment(\.dismiss) private var dismiss
  private enum Field { case phone, code }
  @FocusState private var focused: Field?

  var body: some View {
    NavigationStack {
      Group {
        switch model.step {
        case .phone: phoneStep
        case .code(let pending): codeStep(pending)
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
    Form {
      Section {
        HStack {
          Text("+48").foregroundStyle(.secondary)
          TextField("Phone number", text: $model.phone)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .focused($focused, equals: .phone)
            .onSubmit { Task { await model.sendCode() } }
            .onChange(of: model.phone) { _, new in
              let stripped = ZappkaLoginClient.stripCountryPrefix(new)
              if stripped != new { model.phone = stripped }
            }
        }
      } header: {
        Text("Phone number")
      } footer: {
        Text("The phone number linked to your Żabka account. In the next step, enter the confirmation code.")
      }
      if let error = model.error {
        Section { FieldMessage(text: error, isError: true) }
      }
    }
  }

  private func codeStep(_ pending: ZappkaLoginClient.PendingSignIn) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Confirm with the SMS code")
            .font(.title2.bold())
          Text("Enter the 6-digit code you'll get by SMS at +48 \(Zappka.formatPhone(pending.phone)).")
            .foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 12) {
          OneTimeCodeField(code: $model.code, length: ZappkaLoginModel.codeLength, focus: $focused, field: .code)
            .onChange(of: model.code) {
              if model.canSignIn { Task { await signIn() } }
            }
          if let error = model.error {
            FieldMessage(text: error, isError: true)
          }
        }
        VStack(alignment: .leading, spacing: 12) {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(ceil((model.resendAt ?? context.date).timeIntervalSince(context.date)))
            HStack(spacing: 4) {
              Text("Didn't get the code?")
              if remaining > 0 {
                Text("Wait \(remaining) s").foregroundStyle(.secondary).monospacedDigit()
              } else {
                Button("Send again") { Task { await model.resend() } }
                  .disabled(model.isWorking)
              }
            }
          }
          Button("Change Number") { model.changeNumber() }
            .disabled(model.isWorking)
        }
        .font(.subheadline)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
    }
    .background(Color(.systemGroupedBackground))
  }

  private func signIn() async {
    guard model.canSignIn, case .code(let pending) = model.step,
          let credentials = await model.signIn() else { return }
    onSignIn(credentials, pending.phone)
    dismiss()
  }
}

/// A row of digit boxes over an invisible text field, so the keyboard's "From Messages"
/// suggestion and paste still work.
private struct OneTimeCodeField<Field: Hashable>: View {
  @Binding var code: String
  let length: Int
  var focus: FocusState<Field?>.Binding
  let field: Field

  private var isFocused: Bool { focus.wrappedValue == field }

  var body: some View {
    ZStack {
      TextField("", text: $code)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .foregroundStyle(.clear)
        .tint(.clear)
        .focused(focus, equals: field)
        .accessibilityLabel("Code")
        .onChange(of: code) { _, new in
          let digits = String(new.filter { $0.isASCII && $0.isNumber }.prefix(length))
          if digits != new { code = digits }
        }
      HStack(spacing: 8) {
        ForEach(0..<length, id: \.self) { index in
          box(index)
        }
      }
      .contentShape(.rect)
      .onTapGesture { focus.wrappedValue = field }
      .accessibilityHidden(true)
    }
  }

  private func box(_ index: Int) -> some View {
    let digits = Array(code)
    let active = isFocused && index == min(digits.count, length - 1)
    return RoundedRectangle(cornerRadius: 10)
      .fill(Color(.secondarySystemGroupedBackground))
      .strokeBorder(active ? Color.primary : Color(.separator), lineWidth: active ? 2 : 1)
      .frame(width: 48, height: 58)
      .overlay {
        if index < digits.count {
          Text(String(digits[index])).font(.title2.monospacedDigit())
        }
      }
  }
}

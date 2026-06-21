import SlipStreamKit
import SwiftUI

/// The invitation-redemption flow (F2.5): paste an invite link, validate it, choose a 4-digit
/// PIN, and get signed in. Presented as a sheet from `SignInView`; driven entirely by
/// `InvitationSignupStore.phase`.
public struct InvitationSignupView: View {
  @Environment(InvitationSignupStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var pasteText = ""
  @State private var pin = ""
  @FocusState private var pinFocused: Bool

  public init() {}

  public var body: some View {
    NavigationStack {
      Group {
        switch store.phase {
        case .awaitingToken: awaitingTokenView
        case .validating: validatingView
        case .invalid(let reason): invalidView(reason)
        case .ready(let username): createPINView(username: username)
        case .creatingAccount: creatingAccountView
        }
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .navigationTitle("Sign Up")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }

  // MARK: No token — paste screen

  private var awaitingTokenView: some View {
    VStack(spacing: 16) {
      Image(systemName: "envelope.open")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text("Have an invitation?")
        .font(.title2.bold())
      Text("Paste the invitation link you were sent to create your account.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      TextField("https://…/signup?token=…", text: $pasteText, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .textContentType(.URL)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .lineLimit(1...3)
      PasteButton(payloadType: String.self) { items in
        if let first = items.first {
          pasteText = first.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
      if let error = store.pasteError {
        Text(error).font(.footnote).foregroundStyle(.red)
      }
      continueButton
    }
  }

  private var continueButton: some View {
    Button {
      Task { await store.submitInviteLink(pasteText) }
    } label: {
      Text("Continue").frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }

  // MARK: Validating

  private var validatingView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Validating invitation…").foregroundStyle(.secondary)
    }
    .frame(maxHeight: .infinity)
  }

  // MARK: Invalid / expired

  private func invalidView(_ reason: InvitationSignupStore.InvalidReason) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.orange)
        .accessibilityHidden(true)
      Text(invalidTitle(reason)).font(.title2.bold())
      Text(invalidMessage(reason))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if case .network = reason {
        Button("Retry") { Task { await store.retryValidation() } }
          .buttonStyle(.borderedProminent)
      }
      Button("Try Another Link") {
        pasteText = ""
        pin = ""
        store.reset()
      }
    }
  }

  private func invalidTitle(_ reason: InvitationSignupStore.InvalidReason) -> String {
    switch reason {
    case .network: "Connection Problem"
    default: "Invalid Invitation"
    }
  }

  private func invalidMessage(_ reason: InvitationSignupStore.InvalidReason) -> String {
    switch reason {
    case .expired: "This invitation has expired. Ask your admin for a new link."
    case .used: "This invitation has already been used. Ask your admin for a new link."
    case .notFound, .badToken: "This invitation link is invalid. Ask your admin for a new link."
    case .network: "Couldn't reach the server. Check your connection and try again."
    }
  }

  // MARK: Create PIN

  private func createPINView(username: String) -> some View {
    VStack(spacing: 16) {
      Text("Welcome, \(username)!").font(.title2.bold())
      Text("Create a 4-digit PIN to secure your account.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      PINEntryField(pin: $pin, isFocused: $pinFocused)
        .onChange(of: pin) { _, newValue in maybeSubmit(pin: newValue) }
      if let error = store.submitError {
        Text(error).font(.footnote).foregroundStyle(.red)
      }
    }
    .onAppear { pinFocused = true }
  }

  private var creatingAccountView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Creating your account…").foregroundStyle(.secondary)
    }
    .frame(maxHeight: .infinity)
  }

  // MARK: Submit

  /// Auto-submit once the PIN is complete (mirrors the web `pin.length === 4` effect and
  /// `SignInView`'s focus-gated auto-submit). On a recoverable failure we're back on `.ready`,
  /// so clear the PIN to retype; on success the auth gate swaps this whole sheet away.
  private func maybeSubmit(pin newValue: String) {
    guard pinFocused, newValue.count == 4 else { return }
    Task {
      await store.createAccount(pin: newValue)
      if case .ready = store.phase { pin = "" }
    }
  }
}

import SlipStreamKit
import SwiftUI

public struct SignInView: View {
  @Environment(AuthStore.self) private var auth
  @State private var serverURLString = ""
  @State private var username = ""
  @State private var pin = ""
  @State private var isSubmitting = false
  /// Whether the username is shown as an editable field (true) or collapsed into
  /// a chip with a "Switch User" affordance (false), once a remembered username
  /// is present. Mirrors the web's `showUsernameInput`.
  @State private var isEditingUsername = true
  @State private var hasPopulated = false
  @FocusState private var usernameFocused: Bool
  @FocusState private var pinFocused: Bool
  @Environment(InvitationSignupStore.self) private var signupStore
  @State private var showingSignup = false

  public init() {}

  public var body: some View {
    Form {
      serverSection
      credentialsSection
      if let error = auth.lastError {
        Section {
          Text(message(for: error)).foregroundStyle(.red)
        }
      }
      Section {
        Button(action: submit) {
          if isSubmitting { ProgressView() } else { Text("Sign In") }
        }
        .disabled(!canSubmit || isSubmitting)
      }
      Section {
        Button("Have an invitation? Sign up") {
          signupStore.reset()
          showingSignup = true
        }
      }
    }
    .onAppear(perform: populateIfNeeded)
    .sheet(isPresented: $showingSignup) {
      InvitationSignupView()
    }
  }

  @ViewBuilder private var serverSection: some View {
    Section("Server") {
      TextField("https://slipstream.example.com", text: $serverURLString)
        .textContentType(.URL)
        .keyboardType(.URL)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
      #if DEBUG
        Menu("Dev Servers") {
          ForEach(DevServerPreset.all(config: .current)) { preset in
            Button(preset.name) { applyPreset(preset) }
          }
        }
      #endif
    }
  }

  @ViewBuilder private var credentialsSection: some View {
    Section("Sign In") {
      usernameField
      VStack(alignment: .leading, spacing: 10) {
        Text("PIN")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        PINEntryField(pin: $pin, isFocused: $pinFocused)
          .onChange(of: pin) { _, newValue in maybeAutoSubmit(pin: newValue) }
      }
      .padding(.vertical, 4)
    }
  }

  @ViewBuilder private var usernameField: some View {
    if isEditingUsername {
      TextField("Username", text: $username)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .textContentType(.username)
        .focused($usernameFocused)
        .submitLabel(.next)
        .onSubmit { pinFocused = true }
    } else {
      HStack(spacing: 10) {
        Image(systemName: "person.crop.circle.fill")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Text(username)
          .fontWeight(.medium)
        Spacer()
        Button("Switch User", action: switchUser)
          .font(.subheadline)
      }
    }
  }

  private var trimmedUsername: String {
    username.trimmingCharacters(in: .whitespaces)
  }

  private var canSubmit: Bool {
    guard let url = URL(string: serverURLString) else { return false }
    guard
      ServerURLValidator.isAcceptable(
        url, allowInsecureLocal: DevSupport.allowsInsecureLocalServers)
    else { return false }
    return !trimmedUsername.isEmpty && pin.count == 4
  }

  /// Auto-submit the moment the PIN is complete and a username is present — but
  /// only in response to the user typing (PIN focused), so a pre-filled dev PIN
  /// never logs in on its own. Mirrors the web's `pin.length === 4` effect.
  private func maybeAutoSubmit(pin newValue: String) {
    guard pinFocused, !isSubmitting else { return }
    guard newValue.count == 4, !trimmedUsername.isEmpty else { return }
    submit()
  }

  private func switchUser() {
    username = ""
    pin = ""
    auth.clearError()
    isEditingUsername = true
    usernameFocused = true
  }

  private func submit() {
    guard let url = URL(string: serverURLString), canSubmit else { return }
    isSubmitting = true
    Task {
      // Send (and remember) the trimmed username so it matches the value the
      // `canSubmit` / auto-submit gates validate — stray whitespace never
      // reaches the server or `LastUsernameStore`.
      await auth.signIn(serverURL: url, username: trimmedUsername, pin: pin)
      isSubmitting = false
      // On failure keep the username but clear the PIN (matches the web's
      // `onError: setPin('')`); on success the gate swaps in the signed-in UI.
      if auth.lastError != nil {
        pin = ""
      }
    }
  }

  private func populateIfNeeded() {
    guard !hasPopulated else { return }
    hasPopulated = true
    populateFromDefaults()
    if username.isEmpty, let remembered = auth.lastUsername, !remembered.isEmpty {
      username = remembered
    }
    isEditingUsername = trimmedUsername.isEmpty
    if isEditingUsername {
      usernameFocused = true
    }
  }

  private func populateFromDefaults() {
    #if DEBUG
      let cfg = DevLaunchConfig.current
      if serverURLString.isEmpty, let override = cfg.baseURLOverride,
        ServerURLValidator.isAcceptable(
          override, allowInsecureLocal: DevSupport.allowsInsecureLocalServers)
      {
        serverURLString = override.absoluteString
      }
      if username.isEmpty, let devUser = cfg.devUsername { username = devUser }
      if pin.isEmpty, let devPin = cfg.devPIN { pin = devPin }
    #endif
    if serverURLString.isEmpty, let existing = auth.serverBaseURLString {
      serverURLString = existing
    }
  }

  #if DEBUG
    /// Fill the server field from a preset and, for a local dev target, pre-fill the
    /// throwaway test credentials (pre-fill only — the tester still taps Sign In, so the
    /// real login → JWT → Keychain path is exercised). Sourced from launch env vars, with
    /// a compile-time fallback so it works with zero scheme configuration.
    private func applyPreset(_ preset: DevServerPreset) {
      serverURLString = preset.urlString
      guard let url = URL(string: preset.urlString),
        url.scheme?.lowercased() == "http",
        let host = url.host, ServerURLValidator.isLocalHost(host)
      else { return }
      let cfg = DevLaunchConfig.current
      if username.isEmpty { username = cfg.devUsername ?? DevDefaults.username }
      if pin.isEmpty { pin = cfg.devPIN ?? DevDefaults.pin }
    }

    private enum DevDefaults {
      static let username = "tester"
      static let pin = "1234"
    }
  #endif

  private func message(for error: AuthError) -> String {
    switch error {
    case .invalidPIN: "PIN must be exactly 4 digits."
    case .badCredentials: "Incorrect username or PIN."
    case .server(let status): "Server error (\(status)). Please try again."
    case .network(let detail): "Network error: \(detail)"
    }
  }
}

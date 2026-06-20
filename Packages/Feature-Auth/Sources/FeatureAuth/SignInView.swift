import SlipStreamKit
import SwiftUI

public struct SignInView: View {
  @Environment(AuthStore.self) private var auth
  @State private var serverURLString = ""
  @State private var username = ""
  @State private var pin = ""
  @State private var isSubmitting = false

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
    }
    .onAppear { populateFromDefaults() }
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
      TextField("Username", text: $username)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
      SecureField("4-digit PIN", text: $pin)
        .keyboardType(.numberPad)
        .onChange(of: pin) { _, newValue in
          pin = String(newValue.prefix(4).filter(\.isNumber))
        }
    }
  }

  private var canSubmit: Bool {
    guard let url = URL(string: serverURLString) else { return false }
    guard
      ServerURLValidator.isAcceptable(
        url, allowInsecureLocal: DevSupport.allowsInsecureLocalServers)
    else { return false }
    return !username.isEmpty && pin.count == 4
  }

  private func submit() {
    guard let url = URL(string: serverURLString) else { return }
    isSubmitting = true
    Task {
      await auth.signIn(serverURL: url, username: username, pin: pin)
      isSubmitting = false
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

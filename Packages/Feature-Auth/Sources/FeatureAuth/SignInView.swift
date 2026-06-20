import SwiftUI
import SlipStreamKit

public struct SignInView: View {
    @Environment(AuthStore.self) private var auth
    @State private var serverURLString = ""
    @State private var username = ""
    @State private var pin = ""
    @State private var isSubmitting = false

    public init() {}

    public var body: some View {
        Form {
            Section("Server") {
                TextField("https://slipstream.example.com", text: $serverURLString)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
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
        .onAppear {
            if serverURLString.isEmpty, let existing = auth.serverBaseURLString {
                serverURLString = existing
            }
        }
    }

    private var canSubmit: Bool {
        guard let url = URL(string: serverURLString), url.scheme?.hasPrefix("http") == true else {
            return false
        }
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

    private func message(for error: AuthError) -> String {
        switch error {
        case .invalidPIN: "PIN must be exactly 4 digits."
        case .badCredentials: "Incorrect username or PIN."
        case .server(let status): "Server error (\(status)). Please try again."
        case .network(let detail): "Network error: \(detail)"
        }
    }
}

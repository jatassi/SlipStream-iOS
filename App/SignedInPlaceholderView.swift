import SwiftUI
import SlipStreamKit

/// Placeholder proving auth works end-to-end. Replaced by the library browse UI in Plan 2.
struct SignedInPlaceholderView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        VStack(spacing: 16) {
            if case let .signedIn(user) = auth.state {
                Text("Signed in as \(user.username)").font(.headline)
                Text(user.autoApprove ? "Auto-approve: on" : "Auto-approve: off")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Sign Out") {
                Task { await auth.signOut() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

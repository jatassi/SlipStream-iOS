import SlipStreamKit
import SwiftUI

/// Placeholder for the Settings tab. The settings shell (F7.1) replaces this.
/// Hosts Sign Out so the auth loop stays verifiable end-to-end until F7.1 lands
/// (it replaces the Sign Out that lived in the removed SignedInPlaceholderView).
struct SettingsPlaceholderView: View {
  @Environment(AuthStore.self) private var auth

  var body: some View {
    Form {
      if case .signedIn(let user) = auth.state {
        Section("Account") {
          LabeledContent("Signed in as", value: user.username)
        }
      }
      Section {
        Button("Sign Out", role: .destructive) {
          auth.signOut()
        }
      }
    }
  }
}

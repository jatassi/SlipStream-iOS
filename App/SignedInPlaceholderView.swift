import SlipStreamKit
import SwiftUI

/// Placeholder proving auth + system discovery work end-to-end.
/// Replaced by the library browse UI / tabs in a later feature.
struct SignedInPlaceholderView: View {
  @Environment(AuthStore.self) private var auth
  @Environment(SystemStore.self) private var system

  var body: some View {
    VStack(spacing: 16) {
      if case .signedIn(let user) = auth.state {
        Text("Signed in as \(user.username)").font(.headline)
        Text(user.autoApprove ? "Auto-approve: on" : "Auto-approve: off")
          .font(.caption).foregroundStyle(.secondary)
        Text("Enabled modules: \(moduleList(system.enabledModuleTypes))")
          .font(.caption)
        Text("You can request: \(moduleList(system.requestableModules(for: user)))")
          .font(.caption)
        if !system.portalEnabled {
          Text("Portal is disabled on the server")
            .font(.caption).foregroundStyle(.orange)
        }
      }
      Button("Sign Out") {
        auth.signOut()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .task { await system.refresh() }
  }

  private func moduleList(_ modules: [ModuleType]) -> String {
    modules.isEmpty ? "none" : modules.map(\.rawValue).joined(separator: ", ")
  }
}

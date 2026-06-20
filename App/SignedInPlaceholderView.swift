import SlipStreamKit
import SwiftUI

/// A throwaway `@Observable` that the demo poll stream increments — proves the engine ticks
/// while foregrounded and pauses in the background. Real features replace this with fetched data.
@MainActor
@Observable
private final class PollHeartbeat {
  var count = 0
}

/// Placeholder proving auth + system discovery + polling work end-to-end.
/// Replaced by the library browse UI / tabs in a later feature.
struct SignedInPlaceholderView: View {
  @Environment(AuthStore.self) private var auth
  @Environment(SystemStore.self) private var system
  @Environment(PollingEngine.self) private var poller
  @State private var heartbeat = PollHeartbeat()

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
      Text("Polls: \(heartbeat.count)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
      Button("Sign Out") {
        auth.signOut()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
    .task { await system.refresh() }
    .onAppear {
      poller.resume()
      poller.register(
        PollStream(
          id: "demo-heartbeat",
          interval: .seconds(3),
          perform: { heartbeat.count += 1 }
        ))
    }
    .onDisappear {
      poller.unregister(id: "demo-heartbeat")
    }
  }

  private func moduleList(_ modules: [ModuleType]) -> String {
    modules.isEmpty ? "none" : modules.map(\.rawValue).joined(separator: ", ")
  }
}

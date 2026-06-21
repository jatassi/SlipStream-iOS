import DesignSystem
import SwiftUI

/// Shown in place of *all* portal UI — the pre-auth sign-in screen and the
/// signed-in shell — when the server reports `portalEnabled == false` (F2.6).
/// Mirrors the web `PortalDisabledView` copy verbatim and is built on
/// `EmptyStateView`, so it inherits the force-dark visual identity. Fills the
/// screen with the theme background so it fully replaces whatever it gates.
public struct PortalDisabledView: View {
  public init() {}

  public var body: some View {
    EmptyStateView(
      title: "Requests Portal Disabled",
      systemImage: "nosign",
      description:
        "The external requests portal is currently disabled. Please contact your server administrator."
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignTheme.background)
  }
}

#Preview {
  PortalDisabledView()
    .preferredColorScheme(.dark)
}

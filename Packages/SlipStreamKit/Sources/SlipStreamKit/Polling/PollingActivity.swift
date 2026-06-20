/// The app's foreground state, mapped from SwiftUI's `ScenePhase` by the app layer so the
/// engine stays UI-framework-agnostic (and testable on macOS without SwiftUI). Only `.active`
/// polls; `.inactive` and `.background` hard-stop every driver.
public enum PollingActivity: Sendable {
  case active
  case inactive
  case background
}

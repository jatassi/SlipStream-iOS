/// One pollable view's policy: a stable `id`, a refresh `interval`, an `isEnabled` gate
/// (e.g. download polling is gated on active requests existing), and the async `perform`
/// that fetches. The closures are `@MainActor`, so a stream is `Sendable` (a global-actor
/// closure is Sendable) and safe to hand to the engine's driver tasks.
public struct PollStream: Sendable {
  public let id: String
  public let interval: Duration
  public let isEnabled: @MainActor () -> Bool
  public let perform: @MainActor () async throws -> Void

  public init(
    id: String,
    interval: Duration,
    isEnabled: @escaping @MainActor () -> Bool = { true },
    perform: @escaping @MainActor () async throws -> Void
  ) {
    self.id = id
    self.interval = interval
    self.isEnabled = isEnabled
    self.perform = perform
  }
}

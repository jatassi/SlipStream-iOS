/// Timing seam for the poll loop. Injected so tests drive iterations deterministically
/// without waiting on a real clock. Implementations must throw `CancellationError` when the
/// calling task is cancelled (so cancelling a driver promptly exits its loop).
public protocol PollScheduler: Sendable {
  func sleep(for interval: Duration) async throws
}

/// Production scheduler backed by `Task.sleep(for:)` (ContinuousClock; cancellation-aware).
public struct ContinuousClockScheduler: PollScheduler {
  public init() {}

  public func sleep(for interval: Duration) async throws {
    try await Task.sleep(for: interval)
  }
}

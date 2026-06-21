import Observation

/// Shared, foreground-gated poller — the portal's substitute for websockets. Screens register
/// a `PollStream`; the engine runs each stream's driver only while the app is `.active`, not
/// suspended, and the stream's gate is open, and cancels it otherwise. All timing flows through
/// an injected `PollScheduler` so the engine is unit-tested without a real clock.
@MainActor
@Observable
public final class PollingEngine {
  public private(set) var activity: PollingActivity = .inactive
  public private(set) var isSuspended = false

  @ObservationIgnored private let scheduler: PollScheduler
  @ObservationIgnored private let onUnauthorized: @MainActor () -> Void
  @ObservationIgnored private var streams: [String: PollStream] = [:]
  @ObservationIgnored private var running: Set<String> = []
  @ObservationIgnored private var drivers: [String: Task<Void, Never>] = [:]

  public init(
    scheduler: PollScheduler = ContinuousClockScheduler(),
    onUnauthorized: @escaping @MainActor () -> Void = {}
  ) {
    self.scheduler = scheduler
    self.onUnauthorized = onUnauthorized
  }

  // MARK: Registration

  public func register(_ stream: PollStream) {
    streams[stream.id] = stream
    reevaluate()
  }

  public func unregister(id: String) {
    streams[id] = nil
    running.remove(id)
    stopDriver(id: id)
  }

  // MARK: Lifecycle

  public func setActivity(_ activity: PollingActivity) {
    self.activity = activity
    reevaluate()
  }

  /// Pause all polling immediately — no traffic until `resume()`. Used on a `401`.
  public func suspend() {
    guard !isSuspended else { return }
    isSuspended = true
    reevaluate()
  }

  public func resume() {
    guard isSuspended else { return }
    isSuspended = false
    reevaluate()
  }

  public func isRunning(streamID: String) -> Bool {
    running.contains(streamID)
  }

  /// Re-check every stream's gate + lifecycle and start/stop drivers to match. Called after
  /// lifecycle changes, after every poll (so a stream that just changed shared state can
  /// start/stop its peers), and on demand by callers that mutate a gate's inputs.
  public func reevaluate() {
    for (id, stream) in streams {
      let want = shouldRun(stream)
      if want && !running.contains(id) {
        running.insert(id)
        startDriver(for: stream)
      } else if !want && running.contains(id) {
        running.remove(id)
        stopDriver(id: id)
      }
    }
  }

  // MARK: Internals

  private func shouldRun(_ stream: PollStream) -> Bool {
    activity == .active && !isSuspended && stream.isEnabled()
  }

  private func startDriver(for stream: PollStream) {
    drivers[stream.id] = Task { @MainActor [weak self] in
      await self?.run(stream)
    }
  }

  private func stopDriver(id: String) {
    drivers[id]?.cancel()
    drivers[id] = nil
  }

  private func run(_ stream: PollStream) async {
    while running.contains(stream.id) && !Task.isCancelled {
      do {
        try await stream.perform()
      } catch let APIClientError.http(status, _, _) where status == 401 {
        handleUnauthorized()
        return
      } catch is CancellationError {
        return
      } catch {
        // Transient failure (network blip, decode): keep polling on the next tick.
      }
      reevaluate()  // ripple shared-state changes to peers
      guard running.contains(stream.id) else { return }
      do {
        try await scheduler.sleep(for: stream.interval)
      } catch {
        return  // cancelled while sleeping
      }
    }
  }

  /// A poll came back 401: the JWT expired or was rejected. Stop everything and tell the app.
  ///
  /// The engine owns the 401 for *poll* traffic. `PortalAPIClient` owns it for non-poll requests
  /// via its own `onUnauthorized` hook; F2.4 funnels both into `SessionExpiry`. A single expired
  /// token can reach both paths in one poll cycle, which is safe — `SessionExpiry.handleUnauthorized`
  /// is idempotent (`suspend()` and `AuthStore.signOut()` both no-op when already applied).
  private func handleUnauthorized() {
    // Sets isSuspended + cancels every driver via reevaluate (no-op if already suspended).
    suspend()
    onUnauthorized()
  }
}

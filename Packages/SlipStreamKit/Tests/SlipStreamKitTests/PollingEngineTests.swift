import Foundation
import Testing

@testable import SlipStreamKit

/// A scheduler that parks "forever" (until the driver task is cancelled), so each stream
/// performs exactly once per activation. That single, buffered poll lets tests await a
/// deterministic signal instead of racing a wall clock.
struct ParkingScheduler: PollScheduler {
  func sleep(for interval: Duration) async throws {
    try await Task.sleep(for: .seconds(3600))
  }
}

@MainActor final class EnabledBox { var value = false }

@MainActor
@Suite struct PollingEngineTests {

  @Test func idleEngineRunsNothing() {
    var performed = 0
    let engine = PollingEngine(scheduler: ParkingScheduler())
    engine.register(
      PollStream(
        id: "x", interval: .seconds(3),
        perform: {
          performed += 1
        }))
    // Engine starts .inactive; nothing should run.
    #expect(engine.isRunning(streamID: "x") == false)
    #expect(performed == 0)
  }

  @Test func activatingStartsStreamAndBackgroundStops() async {
    let signal = AsyncStream<Void>.makeStream(of: Void.self)
    let engine = PollingEngine(scheduler: ParkingScheduler())
    engine.register(
      PollStream(
        id: "x", interval: .seconds(3),
        perform: {
          signal.continuation.yield()
        }))

    engine.setActivity(.active)
    var it = signal.stream.makeAsyncIterator()
    await it.next()  // deterministic: first poll happened
    #expect(engine.isRunning(streamID: "x"))

    engine.setActivity(.background)
    #expect(engine.isRunning(streamID: "x") == false)
  }

  @Test func disabledGateDoesNotRunUntilEnabled() async {
    let signal = AsyncStream<Void>.makeStream(of: Void.self)
    let box = EnabledBox()
    let engine = PollingEngine(scheduler: ParkingScheduler())
    engine.register(
      PollStream(
        id: "downloads",
        interval: .seconds(3),
        isEnabled: { box.value },
        perform: { signal.continuation.yield() }
      ))

    engine.setActivity(.active)
    #expect(engine.isRunning(streamID: "downloads") == false)  // gate closed → no traffic

    box.value = true
    engine.reevaluate()
    var it = signal.stream.makeAsyncIterator()
    await it.next()
    #expect(engine.isRunning(streamID: "downloads"))
  }

  @Test func unauthorizedPollSuspendsAndNotifies() async {
    let authSignal = AsyncStream<Void>.makeStream(of: Void.self)
    let engine = PollingEngine(
      scheduler: ParkingScheduler(),
      onUnauthorized: { authSignal.continuation.yield() }
    )
    engine.register(
      PollStream(
        id: "x", interval: .seconds(3),
        perform: {
          throw APIClientError.http(status: 401, message: nil, error: nil)
        }))

    engine.setActivity(.active)
    var it = authSignal.stream.makeAsyncIterator()
    await it.next()  // engine handled the 401
    #expect(engine.isSuspended)
    #expect(engine.isRunning(streamID: "x") == false)
  }

  @Test func suspendStopsAndResumeRestarts() async {
    let signal = AsyncStream<Void>.makeStream(of: Void.self)
    let engine = PollingEngine(scheduler: ParkingScheduler())
    engine.register(
      PollStream(
        id: "x", interval: .seconds(3),
        perform: {
          signal.continuation.yield()
        }))

    engine.setActivity(.active)
    var it = signal.stream.makeAsyncIterator()
    await it.next()
    #expect(engine.isRunning(streamID: "x"))

    engine.suspend()
    #expect(engine.isSuspended)
    #expect(engine.isRunning(streamID: "x") == false)

    engine.resume()
    await it.next()  // polls again after resume
    #expect(engine.isSuspended == false)
    #expect(engine.isRunning(streamID: "x"))
  }
}

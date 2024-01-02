import Dispatch

/// A `SerialExecutor` that dispatches jobs onto the specified `DispatchQueue`.
extension Connection {
  final class Executor {
    // MARK: Lifecycle

    init(queue: DispatchQueue) {
      self.queue = queue
    }

    // MARK: Private

    private let queue: DispatchQueue
  }
}

extension Connection.Executor: SerialExecutor {
  func enqueue(_ job: consuming ExecutorJob) {
    let unownedJob = UnownedJob(job)
    let unownedExecutor = asUnownedSerialExecutor()
    queue.async {
      unownedJob.runSynchronously(on: unownedExecutor)
    }
  }

  func asUnownedSerialExecutor() -> UnownedSerialExecutor {
    UnownedSerialExecutor(ordinary: self)
  }
}

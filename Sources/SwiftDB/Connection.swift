import Dispatch
import Foundation
import SQLite3

/// A single `SQLite` connection.
///
/// Connections are held open until the `Connection` is deallocated.
///
/// `Connection` uses a custom executor to ensure that it operates outside of the cooperative
/// thread pool (since it performs blocking Disk I/O).
public actor Connection {
  // MARK: Lifecycle

  public init(url: URL) async throws {
    // Open the connection, retrieving a `ConnectionHandle`.
    let queue = DispatchQueue(label: "Connection \(UUID().uuidString)")
    let executor = Executor(queue: queue)
    connectionHandle = try await Opener(executor: executor, url: url).open()

    self.queue = queue
    self.executor = executor

    // Initialize the connection.
    try execute("PRAGMA journal_mode = WAL")
    try execute("PRAGMA synchronous = NORMAL")
    try execute("PRAGMA foreign_keys = ON")
  }

  deinit {
    _ = sqlite3_close_v2(connectionHandle)
  }

  // MARK: Public

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    executor.asUnownedSerialExecutor()
  }

  public func execute(_ query: String) throws {
    // Prepare a statement for `query`, retrieving a `StatementHandle`.
    var statementHandle: StatementHandle?
    let prepareResult = sqlite3_prepare_v3(connectionHandle, query, -1, 0, &statementHandle, nil)
    guard prepareResult == SQLITE_OK, let statementHandle else {
      fatalError("TODO: Handle errors")
    }

    // Ensure the statement is finalized following execution (even if execution fails).
    defer {
      sqlite3_finalize(statementHandle)
    }

    // Execute the statement.
    try execute(statementHandle: statementHandle)
  }

  // MARK: Private

  private let connectionHandle: ConnectionHandle
  private let queue: DispatchQueue
  private nonisolated let executor: Executor

  private func execute(statementHandle: StatementHandle) throws {
    // Continuously call `sqlite3_step` until execution is complete, or there's an error.
    while true {
      let stepResult = sqlite3_step(statementHandle)
      switch stepResult {
      case SQLITE_DONE:
        return
      case SQLITE_ROW:
        continue
      default:
        fatalError("TODO: Handle errors")
      }
    }
  }
}

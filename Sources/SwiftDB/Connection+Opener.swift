import Foundation
import SQLite3

extension Connection {
  /// An `actor` responsible for opening a SQLite connection, returning a `ConnectionHandle` from
  /// `open`.
  ///
  /// This `Opener` operates on the passed `Executor`.
  actor Opener {
    // MARK: Lifecycle

    init(executor: Executor, url: URL) {
      self.executor = executor
      self.url = url
    }

    // MARK: Internal

    nonisolated var unownedExecutor: UnownedSerialExecutor {
      executor.asUnownedSerialExecutor()
    }

    /// Opens a `Database.ConnectionHandle` for `url`.
    func open() throws -> ConnectionHandle {
      var connectionHandle: ConnectionHandle?
      let openResult = sqlite3_open_v2(
        url.path,
        &connectionHandle,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX,
        nil
      )
      guard let connectionHandle else {
        fatalError("TODO: Handle errors")
      }

      guard openResult == SQLITE_OK else {
        sqlite3_close(connectionHandle)
        fatalError("TODO: Handle errors")
      }

      return connectionHandle
    }

    // MARK: Private

    private nonisolated let executor: Executor
    private let url: URL
  }
}

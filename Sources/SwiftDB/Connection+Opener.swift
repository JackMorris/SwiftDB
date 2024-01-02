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
        throw Error.connectionOpen(url: url, description: "Cannot allocate memory for handle")
      }

      guard openResult == SQLITE_OK else {
        let errorDescription = Error.errorDescription(connectionHandle: connectionHandle)
        sqlite3_close(connectionHandle)
        throw Error.connectionOpen(url: url, description: errorDescription)
      }

      return connectionHandle
    }

    // MARK: Private

    private nonisolated let executor: Executor
    private let url: URL
  }
}

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
    try execute("PRAGMA synchronous = NORMAL")
    try execute("PRAGMA foreign_keys = ON")
  }

  deinit {
    sqlite3_close_v2(connectionHandle)
  }

  // MARK: Public

  public nonisolated var unownedExecutor: UnownedSerialExecutor {
    executor.asUnownedSerialExecutor()
  }

  @discardableResult
  public func execute(
    _ query: String,
    _ arguments: any ValueConvertible...
  ) throws -> [Row] {
    // Prepare a statement for `query`, retrieving a `StatementHandle`.
    var statementHandle: StatementHandle?
    let prepareResult = sqlite3_prepare_v3(
      connectionHandle,
      query,
      -1,
      0,
      &statementHandle,
      nil
    )
    guard prepareResult == SQLITE_OK, let statementHandle else {
      throw Error.execute(
        query: query,
        description: Error.errorDescription(connectionHandle: connectionHandle)
      )
    }

    // Ensure the statement is finalized following execution (even if execution or binding fails).
    defer {
      sqlite3_finalize(statementHandle)
    }

    // Bind all arguments into the statement.
    var index = 1
    for argumentValue in arguments.map(\.value) {
      try argumentValue.bind(
        connectionHandle: connectionHandle,
        statementHandle: statementHandle,
        index: index,
        query: query
      )
      index += 1
    }

    // Execute the statement.
    return try execute(query: query, statementHandle: statementHandle)
  }

  // MARK: Internal

  @discardableResult
  func transaction<R>(
    _ action: @Sendable (_ connection: isolated Connection) throws -> R
  ) throws -> R {
    try execute("BEGIN TRANSACTION")
    do {
      let result = try action(self)
      try execute("COMMIT TRANSACTION")
      return result
    } catch {
      try execute("ROLLBACK TRANSACTION")
      throw error
    }
  }

  // MARK: Private

  private let connectionHandle: ConnectionHandle
  private let queue: DispatchQueue
  private nonisolated let executor: Executor

  private func execute(query: String, statementHandle: StatementHandle) throws -> [Row] {
    var rows: [Row] = []
    var cachedColumnNames: [String]?

    // Continuously call `sqlite3_step` until execution is complete, or there's an error.
    while true {
      let stepResult = sqlite3_step(statementHandle)

      // Check for errors.
      guard stepResult == SQLITE_ROW || stepResult == SQLITE_DONE else {
        throw Error.execute(
          query: query,
          description: Error.errorDescription(connectionHandle: connectionHandle)
        )
      }

      // Extract the row.
      let columnNames = try {
        if let cachedColumnNames {
          return cachedColumnNames
        } else {
          let columnCount = Int(sqlite3_column_count(statementHandle))
          let columnNames = try (0 ..< columnCount).map { index in
            guard let columnNamePointer = sqlite3_column_name(statementHandle, Int32(index))
            else {
              throw Error.execute(
                query: query,
                description: Error.errorDescription(connectionHandle: connectionHandle)
              )
            }
            return String(cString: columnNamePointer)
          }
          cachedColumnNames = columnNames
          return columnNames
        }
      }()
      if stepResult == SQLITE_ROW {
        rows.append(try (0 ..< columnNames.count).reduce(into: Row()) { row, columnIndex in
          row[columnNames[columnIndex]] = try Value(
            connectionHandle: connectionHandle,
            statementHandle: statementHandle,
            query: query,
            columnIndex: columnIndex,
            columnName: columnNames[columnIndex]
          )
        })
      }

      switch stepResult {
      case SQLITE_DONE:
        return rows
      case SQLITE_ROW:
        // More rows to fetch, continue stepping.
        continue
      default:
        throw Error.execute(
          query: query,
          description: Error.errorDescription(connectionHandle: connectionHandle)
        )
      }
    }
  }
}

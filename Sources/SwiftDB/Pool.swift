import Foundation

public final class Pool: Sendable {
  // MARK: Lifecycle

  public init(url: URL, maxReaders: Int, migrations: [Migration]) {
    initializeWriteConnectionTask = Task {
      let writeConnection = try await Connection(url: url)
      try await Self.initializeDatabase(connection: writeConnection, migrations: migrations)
      return writeConnection
    }
    readConnections = AsyncPool(maxElements: maxReaders) {
      try await Connection(url: url)
    }
  }

  // MARK: Public

  @discardableResult
  public func read<R: Sendable>(
    _ action: @Sendable (_ connection: isolated Connection) throws -> R
  ) async throws -> R {
    try await waitForReady()
    let readConnection = try await readConnections.get()

    do {
      let result = try await readConnection.transaction(action)
      await readConnections.return(readConnection)
      return result
    } catch {
      await readConnections.return(readConnection)
      throw error
    }
  }

  @discardableResult
  public func write<R: Sendable>(
    _ action: @Sendable (_ connection: isolated Connection) throws -> R
  ) async throws -> R {
    try await initializeWriteConnectionTask.value.transaction(action)
  }

  // MARK: Private

  private let initializeWriteConnectionTask: Task<Connection, any Swift.Error>
  private let readConnections: AsyncPool<Connection>

  private static func initializeDatabase(
    connection: Connection,
    migrations: [Migration]
  ) async throws {
    try await connection.execute("PRAGMA journal_mode = WAL")

    try await connection.transaction { connection in
      let currentVersion = try connection
        .execute("PRAGMA user_version")
        .first?["user_version"]?
        .get(Int.self) ?? 0

      let pendingMigrations = migrations.filter { $0.version > currentVersion }
      if !pendingMigrations.isEmpty {
        for migration in pendingMigrations {
          try migration.action(connection)
        }
        try connection.execute("PRAGMA user_version = \(migrations.last?.version ?? 0)")
      }
    }
  }

  private func waitForReady() async throws {
    _ = try await initializeWriteConnectionTask.value
  }
}

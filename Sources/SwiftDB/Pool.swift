import Foundation

public final class Pool: Sendable {
  // MARK: Lifecycle

  public init(url: URL, maxReaders: Int) {
    initializeWriteConnectionTask = Task {
      let writeConnection = try await Connection(url: url)
      try await writeConnection.execute("PRAGMA journal_mode = WAL")
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

  private func waitForReady() async throws {
    _ = try await initializeWriteConnectionTask.value
  }
}
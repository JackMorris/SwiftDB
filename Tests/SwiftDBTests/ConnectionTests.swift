import Foundation
@testable import SwiftDB
import XCTest

final class ConnectionTests: XCTestCase {
  // MARK: Internal

  override func setUp() {
    super.setUp()
    temporaryDirectoryURL = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try! FileManager.default.createDirectory(
      at: temporaryDirectoryURL,
      withIntermediateDirectories: true
    )
  }

  override func tearDown() {
    try! FileManager.default.removeItem(at: temporaryDirectoryURL)
    temporaryDirectoryURL = nil
    super.tearDown()
  }

  /// Verifies that a `Connection` can be opened, and used to execute statements.
  func testConnection() async throws {
    // Given:
    let connection = try await Connection(url: temporaryDatabaseURL())

    // Then:
    try await connection.execute("CREATE TABLE test_table (id INTEGER NOT NULL)")
  }

  /// Verifies that an error is thrown when opening a `Connection` at an invalid `URL`.
  func testConnectionOpenError() async throws {
    await assertThrows(
      try await Connection(url: URL(filePath: "")),
      "No failure when opening connection"
    )
  }

  /// Verifies than an error is thrown when executing a malformed query against a `Connection`.
  func testExecutionError() async throws {
    // Given:
    let connection = try await Connection(url: temporaryDatabaseURL())

    // Then:
    await assertThrows(
      try await connection.execute("NOT_A_QUERY"),
      "No failure when executing query"
    )
  }

  /// Verifies that values can be bound into queries, before being fetched.
  func testFetchValues() async throws {
    // Given:
    let connection = try await Connection(url: temporaryDatabaseURL())

    // When:
    try await connection.execute("CREATE TABLE test (id INTEGER NOT NULL, info TEXT)")
    try await connection.execute("INSERT INTO test VALUES (1, ?)", "info_1")
    try await connection.execute("INSERT INTO test VALUES (2, ?)", "info_2")
    try await connection.execute("INSERT INTO test VALUES (3, ?)", Value.null)
    let rows = try await connection.execute("SELECT * FROM test ORDER BY id ASC")

    // Then:
    // Verify `rows` directly.
    XCTAssertEqual(rows[0], ["id": .integer(1), "info": .text("info_1")])
    XCTAssertEqual(rows[1], ["id": .integer(2), "info": .text("info_2")])
    XCTAssertEqual(rows[2], ["id": .integer(3), "info": .null])

    // Verify extracting individual values from `rows`.
    XCTAssertEqual(try rows[0]["id"]?.get(), 1)
    XCTAssertEqual(try rows[1]["id"]?.get(), 2)
    XCTAssertEqual(try rows[2]["id"]?.get(), 3)
    XCTAssertEqual(try rows[0]["info"]?.get(), "info_1")
    XCTAssertEqual(try rows[1]["info"]?.get(), "info_2")
    XCTAssertEqual(try rows[2]["info"]?.get(), String?.none)
  }

  func testPool() async throws {
    // Given:
    let pool = Pool(url: temporaryDatabaseURL(), maxReaders: 8)
    try await pool.write { try $0.execute("CREATE TABLE test (id INTEGER NOT NULL)") }

    // "Concurrent" writes.
    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 100 {
        group.addTask {
          _ = try await pool.write { connection in
            try connection.execute("INSERT INTO test VALUES (?)", Int.random(in: 0 ... 1000))
          }
        }
      }
      try await group.waitForAll()
    }

    // Concurrent reads.
    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 1000 {
        group.addTask {
          _ = try await pool.read { connection in
            try connection.execute("SELECT * FROM test")
          }
        }
      }
      try await group.waitForAll()
    }
  }

  // MARK: Private

  /// A `URL` for a temporary directory that can be used throughout this test.
  ///
  /// This directory is deleted during tear down.
  private var temporaryDirectoryURL: URL!

  /// Returns a `URL` suitable for use for a temporary database.
  private func temporaryDatabaseURL() -> URL {
    temporaryDirectoryURL.appending(path: UUID().uuidString, directoryHint: .notDirectory)
  }

  /// Asserts that `body` throws an error, failing the current test with `message` if not.
  private func assertThrows<R>(
    _ body: @autoclosure () async throws -> R,
    _ message: String
  ) async -> Void {
    do {
      _ = try await body()
      XCTFail(message)
    } catch {}
  }
}

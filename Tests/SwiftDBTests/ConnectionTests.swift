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

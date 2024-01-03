import Foundation
import SQLite3

enum Error: Swift.Error {
  /// An error occurred when opening a connection at `url`.
  case connectionOpen(url: URL, description: String)
  /// An error occurred when executing `query`.
  case execute(query: String, description: String)
  /// `Value` cannot be converted to the expected type (`expectedTargetType`).
  case unexpectedValueType(value: Value, expectedTargetType: String)
  /// There was an error binding `value` to `argumentIndex` in `query`.
  case argumentBind(query: String, argumentIndex: Int, value: Value, description: String)
  /// There was an error whilst extracting a result value from the executed `query`.
  case resultValue(query: String, column: String)

  // MARK: Internal

  /// Returns a description of the last error that occurred whilst using `connectionHandle`.
  static func errorDescription(connectionHandle: ConnectionHandle) -> String {
    let errorCode = Int(sqlite3_errcode(connectionHandle))
    let errorMessage = String(cString: sqlite3_errmsg(connectionHandle), encoding: .utf8) ??
      "-"
    return "SQLite error \(errorCode): \(errorMessage)"
  }
}

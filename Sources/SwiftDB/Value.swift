import Foundation
import SQLite3

// MARK: - Value

public enum Value: Sendable {
  case null
  case integer(Int64)
  case real(Double)
  case text(String)
  case blob(Data)

  // MARK: Lifecycle

  /// Initializes a `Value` from the result of an executed `statement`, extracting the value for
  /// `columnIndex`.
  init(
    connectionHandle: ConnectionHandle,
    statementHandle: StatementHandle,
    query: String,
    columnIndex: Int,
    columnName: String
  ) throws {
    switch sqlite3_column_type(statementHandle, Int32(columnIndex)) {
    case SQLITE_NULL:
      self = .null
    case SQLITE_INTEGER:
      self = .integer(sqlite3_column_int64(statementHandle, Int32(columnIndex)))
    case SQLITE_FLOAT:
      self = .real(sqlite3_column_double(statementHandle, Int32(columnIndex)))
    case SQLITE_TEXT:
      guard let textPointer = sqlite3_column_text(statementHandle, Int32(columnIndex)) else {
        throw Error.resultValue(query: query, column: columnName)
      }
      self = .text(String(cString: textPointer))
    case SQLITE_BLOB:
      let byteLength = sqlite3_column_bytes(statementHandle, Int32(columnIndex))
      if byteLength > 0 {
        guard let bytes = sqlite3_column_blob(statementHandle, Int32(columnIndex)) else {
          throw Error.resultValue(query: query, column: columnName)
        }
        self = .blob(Data(bytes: bytes, count: Int(byteLength)))
      } else {
        self = .blob(Data())
      }
    default:
      throw Error.execute(
        query: query,
        description: Error.errorDescription(connectionHandle: connectionHandle)
      )
    }
  }

  // MARK: Internal

  func get<T: ValueConvertible>(_: T.Type = T.self) throws -> T {
    try T(value: self)
  }

  /// Binds this `Value` into `statementHandle` at the specified `index`.
  func bind(
    connectionHandle: ConnectionHandle,
    statementHandle: StatementHandle,
    index: Int,
    query: String
  ) throws {
    let bindResult = switch self {
    case .null:
      sqlite3_bind_null(statementHandle, Int32(index))
    case .integer(let int):
      sqlite3_bind_int64(statementHandle, Int32(index), int)
    case .real(let double):
      sqlite3_bind_double(statementHandle, Int32(index), double)
    case .text(let string):
      sqlite3_bind_text(
        statementHandle,
        Int32(index),
        string,
        -1,
        Self.transientDestructorType
      )
    case .blob(let data):
      data.withUnsafeBytes { bytes in
        sqlite3_bind_blob(
          statementHandle,
          Int32(index),
          bytes.baseAddress,
          Int32(bytes.count),
          Self.transientDestructorType
        )
      }
    }
    guard bindResult == SQLITE_OK else {
      throw Error.argumentBind(
        query: query,
        argumentIndex: index,
        value: self,
        description: Error.errorDescription(connectionHandle: connectionHandle)
      )
    }
  }

  // MARK: Private

  /// See https://www.sqlite.org/c3ref/c_static.html.
  private static let transientDestructorType = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
  )
}

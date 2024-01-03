import Foundation

// MARK: - ValueConvertible

/// A type that can be converted to/from a `Value`.
public protocol ValueConvertible: Sendable {
  var value: Value { get }
  init(value: Value) throws
}

extension Value: ValueConvertible {
  public var value: Value { self }
  public init(value: Value) { self = value }
}

extension Optional: ValueConvertible where Wrapped: ValueConvertible {
  public var value: Value {
    if let self {
      self.value
    } else {
      .null
    }
  }

  public init(value: Value) throws {
    switch value {
    case .null:
      self = nil
    default:
      self = try Wrapped(value: value)
    }
  }
}

extension Int: ValueConvertible {
  public var value: Value {
    .integer(Int64(self))
  }

  public init(value: Value) throws {
    switch value {
    case .integer(let integer):
      self = Int(integer)
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "Int")
    }
  }
}

extension Double: ValueConvertible {
  public var value: Value {
    .real(self)
  }

  public init(value: Value) throws {
    switch value {
    case .real(let real):
      self = real
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "Double")
    }
  }
}

extension String: ValueConvertible {
  public var value: Value {
    .text(self)
  }

  public init(value: Value) throws {
    switch value {
    case .text(let text):
      self = text
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "String")
    }
  }
}

extension Data: ValueConvertible {
  public var value: Value {
    .blob(self)
  }

  public init(value: Value) throws {
    switch value {
    case .blob(let blob):
      self = blob
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "Data")
    }
  }
}

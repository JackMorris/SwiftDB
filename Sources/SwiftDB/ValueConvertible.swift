import Foundation

// MARK: - ValueConvertible

/// A type that can be converted to/from a `Value`.
protocol ValueConvertible {
  var value: Value { get }
  init(value: Value) throws
}

extension Value: ValueConvertible {
  var value: Value { self }
  init(value: Value) { self = value }
}

extension Optional: ValueConvertible where Wrapped: ValueConvertible {
  var value: Value {
    if let self {
      self.value
    } else {
      .null
    }
  }

  init(value: Value) throws {
    switch value {
    case .null:
      self = nil
    default:
      self = try Wrapped(value: value)
    }
  }
}

extension Int: ValueConvertible {
  var value: Value {
    .integer(Int64(self))
  }

  init(value: Value) throws {
    switch value {
    case .integer(let integer):
      self = Int(integer)
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "Int")
    }
  }
}

extension Double: ValueConvertible {
  var value: Value {
    .real(self)
  }

  init(value: Value) throws {
    switch value {
    case .real(let real):
      self = real
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "Double")
    }
  }
}

extension String: ValueConvertible {
  var value: Value {
    .text(self)
  }

  init(value: Value) throws {
    switch value {
    case .text(let text):
      self = text
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "String")
    }
  }
}

extension Data: ValueConvertible {
  var value: Value {
    .blob(self)
  }

  init(value: Value) throws {
    switch value {
    case .blob(let blob):
      self = blob
    default:
      throw Error.unexpectedValueType(value: value, expectedTargetType: "Data")
    }
  }
}

public struct Migration: Sendable {
  // MARK: Lifecycle

  public init(version: Int, action: @escaping Action) {
    self.version = version
    self.action = action
  }

  // MARK: Public

  public typealias Action = @Sendable (isolated Connection) throws -> Void

  public var version: Int
  public var action: Action
}

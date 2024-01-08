/// A migration that can be applied to a database.
///
/// Migration versions must be `>0`, and migrations must be applied in increasing-version order.
/// Migrations must _not_ modify their `action` for the same `version`.
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

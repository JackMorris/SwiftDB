/// An async-aware element pool.
///
/// Elements can be fetched with `get()`. If an element is available, it will be returned
/// immediately. If not available, it will be built on demand.
///
/// If the maximum number of elements have already been built, the caller will suspend until an
/// element is available.
///
/// Elements must be returned with `return(_ element:)` once they are no longer needed.
actor AsyncPool<Element: Sendable> {
  // MARK: Lifecycle

  init(maxElements: Int, elementBuilder: @escaping @Sendable () async throws -> Element) {
    precondition(maxElements > 0)
    self.maxElements = maxElements
    self.elementBuilder = elementBuilder
  }

  // MARK: Internal

  /// Retrieves an element from the pool.
  ///
  /// Will suspend if an element is not yet available.
  func get() async throws -> Element {
    // Attempt to return an element directly from the pool.
    if let element = elements.popLast() {
      return element
    }

    // Attempt to build a new element, since there are no free elements.
    if builtElements < maxElements {
      builtElements += 1
      do {
        return try await elementBuilder()
      } catch {
        // Failed to build the element, so allow further elements to be constructed.
        builtElements -= 1
        throw error
      }
    }

    // Wait for an element to become available.
    return await withCheckedContinuation { continuation in
      continuationQueue.enqueue(continuation)
    }
  }

  /// Returns an element to the pool.
  func `return`(_ element: Element) {
    if let nextContinuation = continuationQueue.dequeue() {
      // A task is waiting for this element, so provide it directly.
      nextContinuation.resume(returning: element)
    } else {
      // Return the element back to the pool.
      elements.append(element)
    }
  }

  // MARK: Private

  private let maxElements: Int
  private var builtElements = 0
  private let elementBuilder: () async throws -> Element
  private var elements: [Element] = []
  private var continuationQueue = Queue<CheckedContinuation<Element, Never>>()
}

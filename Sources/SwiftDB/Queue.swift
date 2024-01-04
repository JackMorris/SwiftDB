/// A simple FIFO queue for `Element`s.
struct Queue<Element> {
  // MARK: Internal

  /// Enqueue a new `Element` to the queue.
  mutating func enqueue(_ element: Element) {
    entryStack.append(element)
  }

  /// Dequeue the next `Element` from the queue.
  mutating func dequeue() -> Element? {
    if let next = exitStack.popLast() {
      return next
    }

    // `exitStack` is empty, move over `entryStack`.
    exitStack = entryStack.reversed()
    entryStack = []

    return exitStack.popLast()
  }

  // MARK: Private

  private var entryStack: [Element] = []
  private var exitStack: [Element] = []
}

//
//  Task+Extensions.swift
//  Runes
//
//  Created by Michael Long on 12/22/25.
//

import Combine

extension Task {
    /// Returns task handle as AnyCancellable
    /// Cancelling the AnyCancellable will cancel the Task.
    public var asAnyCancellable: AnyCancellable {
        AnyCancellable { self.cancel() }
    }

    /// Stores a cancellable wrapper for this Task into a Set<AnyCancellable>.
    @discardableResult
    public func store(in set: inout Set<AnyCancellable>) -> Task {
        set.insert(self.asAnyCancellable)
        return self
    }
}

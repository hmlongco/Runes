//
//  SharedAsyncStream+Publisher.swift
//  Runes
//
//  Created by Michael Long on 12/28/25.
//

import Combine
import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

public extension SharedAsyncStream {

    /// Optional Combine stream for AsyncValues.
    /// ```swift
    /// .onReceive(viewModel.service.integers.publisher) { next in
    ///     print("Received: \(next)")
    ///     self.value = next.value
    /// }
    /// ```
    /// Elements are returned main thread for all cases: .loading, .value, .error, and .cancelled.
    var publisher: AnyPublisher<Element, Never> {
        Publisher(parent: self)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Internal Combine publisher (no Subjects)

    private struct Publisher: Combine.Publisher {
        typealias Output = Element
        typealias Failure = Never

        unowned let parent: SharedAsyncStream<Value>

        func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = Subscription(parent: parent, downstream: subscriber)
            subscriber.receive(subscription: subscription)
        }

        private final class Subscription<S: Subscriber>: Combine.Subscription, @unchecked Sendable
        where S.Input == Element, S.Failure == Never {

            private let parent: SharedAsyncStream<Value>
            private var downstream: S?

            private var token: UUID?
            private var demand: Subscribers.Demand = .none
            private let demandLock = NSLock()

            init(parent: SharedAsyncStream<Value>, downstream: S) {
                self.parent = parent
                self.downstream = downstream
            }

            func request(_ newDemand: Subscribers.Demand) {
                guard newDemand > .none else { return }

                demandLock.lock()
                demand += newDemand
                let shouldStart = (token == nil)
                demandLock.unlock()

                if shouldStart {
                    token = parent.addAsyncObserver(
                        yield: { [weak self] element in
                            self?.push(element)
                        },
                        finish: { [weak self] in
                            self?.complete()
                        }
                    )
                }
            }

            func cancel() {
                if let token {
                    parent.removeAsyncObserver(token)
                }
                token = nil
                downstream = nil
            }

            private func push(_ element: Element) {
                demandLock.lock()
                guard demand > .none else { demandLock.unlock(); return }
                demand -= 1
                demandLock.unlock()

                _ = downstream?.receive(element)
            }

            private func complete() {
                downstream = nil
                if let token {
                    parent.removeAsyncObserver(token)
                }
                token = nil
            }
        }
    }
}

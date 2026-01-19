//
//  SharedAsyncStream+Assign.swift
//  Runes
//
//  Created by Michael Long on 12/29/25.
//

import Foundation

extension SharedAsyncStream {
    /// Registers a observer to observe async events and assign the Element. This can be used as an alternative to for/await streams.
    /// ```swift
    /// service.assign(\.someElement, on: self)
    /// ```
    /// The observer must be a reference type, as that's used to automatically remove the observer when the observing object goes out of scope.
    ///
    /// Assignment will always occur on the MainActor.
    public func assign<O: AnyObject>(_ keyPath: ReferenceWritableKeyPath<O, Element>, on observer: O) {
        let key = UUID()
        let sendableWritableKeyPath = SendableWritableKeyPath(observer: observer, keyPath: keyPath)
        addAsyncObserver(
            key: key,
            observer: observer,
            yield: { [sendableWritableKeyPath] element in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        sendableWritableKeyPath.observer?[keyPath: sendableWritableKeyPath.keyPath] = element
                   }
                } else {
                    RunLoop.main.perform {
                        sendableWritableKeyPath.observer?[keyPath: sendableWritableKeyPath.keyPath] = element
                    }
                }
            },
            finish: { [weak self] in
                self?.removeAsyncObserver(key)
            }
        )
    }

    /// Registers a observer to observe async events and assign the Value, if any. This can be used as an alternative to for/await streams.
    /// ```swift
    /// service.assign(\.someValue, on: self)
    /// ```
    /// The observer must be a reference type, as that's used to automatically remove the observer when the observing object goes out of scope.
    ///
    /// Assignment will always occur on the MainActor.
    public func assign<O: AnyObject>(_ keyPath: ReferenceWritableKeyPath<O, Value?>, on observer: O) {
        let key = UUID()
        let sendableWritableKeyPath = SendableWritableKeyPath(observer: observer, keyPath: keyPath)
        addAsyncObserver(
            key: key,
            observer: observer,
            yield: { [sendableWritableKeyPath] element in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        sendableWritableKeyPath.observer?[keyPath: sendableWritableKeyPath.keyPath] = element.value
                    }
                } else {
                    RunLoop.main.perform {
                        sendableWritableKeyPath.observer?[keyPath: sendableWritableKeyPath.keyPath] = element.value
                    }
                }
            },
            finish: { [weak self] in
                self?.removeAsyncObserver(key)
            }
        )
    }

    /// Registers a observer to observe async events and assign the Value, if any. This can be used as an alternative to for/await streams.
    /// ```swift
    /// service.assign(\.someValue, on: self)
    /// ```
    /// The observer must be a reference type, as that's used to automatically remove the observer when the observing object goes out of scope.
    ///
    /// Assignment will always occur on the MainActor.
    public func assign<O: AnyObject>(_ keyPath: ReferenceWritableKeyPath<O, Value>, on observer: O, defaultValue: Value) {
        let key = UUID()
        let sendableWritableKeyPath = SendableWritableKeyPath(observer: observer, keyPath: keyPath)
        addAsyncObserver(
            key: key,
            observer: observer,
            yield: { [sendableWritableKeyPath] element in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        sendableWritableKeyPath.observer?[keyPath: sendableWritableKeyPath.keyPath] = element.value ?? defaultValue
                    }
                } else {
                    RunLoop.main.perform {
                        sendableWritableKeyPath.observer?[keyPath: sendableWritableKeyPath.keyPath] = element.value ?? defaultValue
                    }
                }
            },
            finish: { [weak self] in
                self?.removeAsyncObserver(key)
            }
        )
    }

    private struct SendableWritableKeyPath<Object: AnyObject, Variable>: @unchecked Sendable {
        weak var observer: Object?
        let keyPath: ReferenceWritableKeyPath<Object, Variable>
    }
}

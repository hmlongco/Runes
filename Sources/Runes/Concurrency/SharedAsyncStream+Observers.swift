//
//  SharedAsyncStream+Observers.swift
//  Runes
//
//  Created by Michael Long on 12/29/25.
//

import Foundation

extension SharedAsyncStream {
    ///  Registers a change observer to observe async events. This can be used as an alternative to for/await streams.
    ///  ```swift
    ///  service.addObserver(self) { element in
    ///     print("Observed \(element)")
    /// }
    /// ```
    /// The observer must be a reference type, as that's used to automatically remove the observer when the observing object goes out of scope.
    @discardableResult
    public func addObserver<O: AnyObject>(_ observer: O, onNext: @escaping @Sendable (Element) -> Void) -> UUID {
        let key = UUID()
        addAsyncObserver(key: key, observer: observer, yield: onNext) { [weak self] in
            self?.removeAsyncObserver(key)
        }
        return key
    }

    ///  Removes observer identified by token returned by addObserver.
    ///
    ///  Manual removal isn't normally needed, since addObserver will automatically cleanup when the observing object goes out of scope.
    public func removeObserver(_ key: UUID) {
        removeAsyncObserver(key)
    }
}

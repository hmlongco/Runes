//
//  OnNotification.swift
//  Runes
//
//  Created by Michael Long on 1/1/26.
//

#if canImport(UIKit)
import Foundation
import UIKit

public class OnNotification {

    private let onNotify: (Notification) -> Void
    private var observer: NSObjectProtocol? = nil

    public init(_ name: Notification.Name, onNotify: @escaping (Notification) -> Void) {
        self.onNotify = onNotify

        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.onNotify(notification)
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

}

public class OnBecomeActiveNotification: OnNotification {
    public init(onActive: @escaping () -> Void) {
        super.init(UIApplication.didBecomeActiveNotification, onNotify: { _ in onActive() })
    }
}

public class OnEnterBackgroundNotification: OnNotification {
    public init(onBackground: @escaping () -> Void) {
        super.init(UIApplication.didEnterBackgroundNotification, onNotify: { _ in onBackground() })
    }
}
#endif

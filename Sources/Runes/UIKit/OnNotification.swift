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

    private var observer: NSObjectProtocol? = nil
    private let perform: (Notification) -> Void

    public init(_ name: Notification.Name, perform: @escaping (Notification) -> Void) {
        self.perform = perform

        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.perform(notification)
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

}

extension OnNotification {
    public static func didBecomeActive(perform: @escaping () -> Void) -> OnNotification {
        .init(UIApplication.didBecomeActiveNotification, perform: { _ in perform() })
    }

    public static func didEnterBackground(perform: @escaping () -> Void) -> OnNotification {
        .init(UIApplication.didEnterBackgroundNotification, perform: { _ in perform() })
    }
}
#endif

//
//  withTracking.swift
//  Runes
//
//  Created by Michael Long on 11/16/25.
//

import Observation
import Foundation

//public func withTracking<T: Sendable>(of value: @Sendable @escaping () -> T, execute: @Sendable @escaping (T) -> Void) {
//    withObservationTracking { [weak self] in
//        execute(value())
//    } onChange: { [weak self] in
//        RunLoop.current.perform {
//            withObservationTracking(of: value(), execute: execute)
//        }
//    }
//}

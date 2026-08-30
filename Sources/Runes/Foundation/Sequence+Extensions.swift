//
//  Sequence+Extensions.swift
//  Modules
//
//  Created by Michael Long on 8/15/26.
//

import Foundation

extension Sequence {
    func keyed<Key: Hashable, Value>(by key: (Element) -> Key, value: (Element) -> Value) -> [Key: Value] {
        Dictionary(
            map { (key($0), value($0)) },
            uniquingKeysWith: { _, new in new }
        )
    }
}

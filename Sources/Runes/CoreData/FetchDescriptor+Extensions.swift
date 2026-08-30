//
//  FetchDescriptor+Extensions.swift
//  Modules
//
//  Created by Michael Long on 8/15/26.
//

import Foundation
import SwiftData

extension FetchDescriptor {
    public init(fetchLimit: Int? = nil,  fetchOffset: Int? = nil, predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) {
        self.init(predicate: predicate, sortBy: sortBy)
        self.fetchLimit = fetchLimit
        self.fetchOffset = fetchOffset
    }
}

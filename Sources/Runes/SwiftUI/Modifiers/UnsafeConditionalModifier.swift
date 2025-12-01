//
//  UnsafeConditionalModifier.swift
//  Runes
//
//  Created by Michael Long on 11/2/25.
//

import SwiftUI

public extension View {
    /// Allows conditional view modifiers to be applied to a given view.
    /// ```swift
    /// ScrollView {
    ///     Text("test")
    /// }
    /// .unsafeConditionalModifier {
    ///     if #available(iOS 17, *) {
    ///         $0.scrollBounceBehavior(.always)
    ///     }
    /// }
    /// ```
    /// This modifier is unsafe if used incorrectly, and could result in state and/or data loss. Any condition(s) tested should remain true
    /// for the lifetime of the running application.
    @inlinable
    func unsafeConditionalModifier(@ViewBuilder modify: (Self) -> some View) -> some View {
        modify(self)
    }
}

//func test() -> some View {
//    ScrollView {
//        Text("test")
//    }
//    .unsafeConditionalModifier {
//        if #available(iOS 17, *) {
//            $0.scrollBounceBehavior(.always)
//        }
//    }
//}

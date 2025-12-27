//
//  Optionals.swift
//  Runes
//
//  Created by Michael Long on 10/7/24.
//

import Foundation

public protocol OptionalProtocol {
    associatedtype Wrapped

    /// Adds hasValue variable check to optional values.
    ///
    /// The following code prints true if the passed string value exists, or false
    /// if the passed value is nil.
    /// ``` swift
    /// func test(string: String?) {
    ///     if string.hasValue {
    ///         print("true")
    ///     } else {
    ///         print("false")
    ///     }
    /// }
    /// ```
    /// This is somewhat more performant than using the nil coalescing operator and its RHS autoclosure.
    var hasValue: Bool { get }

    var isNil: Bool { get }
    var isNotNil: Bool { get }

    var wrappedValue: Wrapped? { get }
}

extension Optional: OptionalProtocol {
    @inlinable public var hasValue: Bool {
        switch self {
        case .some:
            true
        case .none:
            false
        }
    }

    @inlinable public var isNil: Bool {
        self == nil
    }

    @inlinable public var isNotNil: Bool {
        self != nil
    }

    @inlinable public var wrappedValue: Wrapped? {
        if case .some(let value) = self {
            value
        } else {
            nil
        }
    }
}

extension Optional where Wrapped: RangeReplaceableCollection {
    /// Adds orEmpty variable to optional Strings, Arrays, Sets, and other collections that implement the
    /// RangeReplaceableCollection protocol.
    ///
    /// The following code sets newValue to the passed string value if if exists, or to an empty string
    /// if the passed value is nil.
    /// ``` swift
    /// func test(value: String?) {
    ///     let newValue = value.orEmpty
    /// }
    /// ```
    /// This is somewhat more performant than using the nil coalescing operator and its RHS autoclosure.
    @inlinable public var orEmpty: Wrapped {
        switch self {
        case .some(let value):
            value
        case .none:
            Wrapped()
        }
    }

    @inlinable var isNilOrEmpty: Bool {
        self == nil || self!.isEmpty
    }

    @inlinable var isNotNilOrEmpty: Bool {
        !isNilOrEmpty
    }
}

public protocol EmptyDictionaryProtocol {
    static var empty: Self { get }
}

extension Dictionary: EmptyDictionaryProtocol {
    @inlinable public static var empty: Self { [:] }
}

extension Optional where Wrapped: EmptyDictionaryProtocol {
    /// Adds orEmpty convenience variable to optional Dictionaries.
    ///
    /// The following code sets newValues to the passed dictionary if if exists, or to a new empty dictionary
    /// if the passed value is nil.
    /// ``` swift
    /// func test(values: [String: String]?) {
    ///     let newValues = values.orEmpty
    /// }
    /// ```
    /// This is somewhat more performant than using the nil coalescing operator and its RHS autoclosure.
    @inlinable public var orEmpty: Wrapped {
        switch self {
        case .some(let value):
            value
        case .none:
            Wrapped.empty
        }
    }

//    @inlinable var isNilOrEmpty: Bool {
//        self == nil || self!.count == 0
//    }
//
//    @inlinable var isNotNilOrEmpty: Bool {
//        !isNilOrEmpty
//    }
}

extension Optional where Wrapped == Bool {
    /// Adds orTrue variable to optional Boolean values.
    ///
    /// The following example prints true if the optional value is true, or if nil is passed instead.
    /// ``` swift
    /// func test(value: Bool?) {
    ///     if value.orTrue {
    ///         print("true")
    ///     } else {
    ///         print("false")
    ///     }
    /// }
    /// ```
    /// This is somewhat more performant than using the nil coalescing operator and its RHS autoclosure.
    @inlinable public var orTrue: Wrapped {
        switch self {
        case .some(let value):
            value
        case .none:
            true
        }
    }
    /// Adds orFalse variable to optional Boolean values.
    ///
    /// The following example prints false if the optional value is false, or if nil is passed instead.
    /// ``` swift
    /// func test(value: Bool?) {
    ///     if value.orFalse {
    ///         print("false")
    ///     } else {
    ///         print("true")
    ///     }
    /// }
    /// ```
    /// This is somewhat more performant than using the nil coalescing operator and its RHS autoclosure.
    @inlinable public var orFalse: Wrapped {
        switch self {
        case .some(let value):
            value
        case .none:
            false
        }
    }
}

extension Optional where Wrapped: Numeric {
    /// Adds orZero variable to optional numeric values (Ints, Doubles, Decimals, etc.).
    ///
    /// The following example prints the optional value, or zero if nil is passed instead.
    /// ``` swift
    /// func test(value: Int?) {
    ///     print("The number is \(value.orZero)"
    /// }
    /// ```
    /// This is somewhat more performant than using the nil coalescing operator and its RHS autoclosure.
    @inlinable public var orZero: Wrapped {
        switch self {
        case .some(let value):
            value
        case .none:
            .zero
        }
    }
}

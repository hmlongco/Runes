//
//  UnknownCaseDecodable.swift
//  Runes
//
//  Based on a concept from: https://medium.com/@sharaev_vl/08e54fa37aef

import Foundation

/// Automatically defaults to an unknown case if an unknown value is supplied to decodable.
/// ```
///    enum Status: String, UnknownCaseDecodable {
///        case new
///        case inProgress = "progress"
///        case done
///        case unknown
///    }
/// ```
public protocol UnknownCaseDecodable: Decodable where Self: RawRepresentable {
    associatedtype DecodeType: Decodable where DecodeType == RawValue
    static var unknown: Self { get }
    var rawValue: DecodeType { get }
}

extension UnknownCaseDecodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(DecodeType.self)
        self = .init(rawValue: rawValue) ?? Self.unknown
    }
}

#if DEBUG
private enum UnknownCaseDecodableStatus: String, UnknownCaseDecodable {
    case new
    case inProgress = "progress"
    case done
    case unknown
}
#endif

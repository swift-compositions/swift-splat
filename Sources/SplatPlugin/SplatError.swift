import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SplatError: Swift::Error, CustomStringConvertible {
    case noTargetStruct(String)
    case noProperties

    var description: String {
        switch self {
        case .noTargetStruct(let name):
            return "@Splat requires a nested struct named '\(name)'"

        case .noProperties:
            return "Target struct has no stored properties to splat"
        }
    }
}

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SplatError: Swift::Error, CustomStringConvertible {
    case noTargetStruct(String)
    case noProperties
}

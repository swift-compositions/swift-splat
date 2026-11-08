import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros


extension SplatMacro {
    struct PropertyInfo {
        let name: String
        let type: TypeSyntax
        let doc: String?
        let path: [String]
        let defaultValue: InitializerClauseSyntax?

        init(
            name: String,
            type: TypeSyntax,
            doc: String?,
            path: [String] = [],
            defaultValue: InitializerClauseSyntax? = nil
        ) {
            self.name = name
            self.type = type
            self.doc = doc
            self.path = path
            self.defaultValue = defaultValue
        }
    }
}

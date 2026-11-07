import SwiftSyntax
import SwiftSyntaxBuilder

enum ExhaustiveCases {

    static func generate(
        properties: [SplatMacro.PropertyInfo],
        structName: String
    ) -> DeclSyntax? {
        guard !properties.isEmpty else { return nil }
        guard properties.allSatisfy({ $0.path.isEmpty }) else { return nil }
        guard properties.allSatisfy({ isBoolOptional($0.type) }) else { return nil }

        let chain = buildChain(properties: properties, structName: structName)

        return """
            public static let allCases: [\(raw: structName)] = {
                let _v: [Bool?] = [true, false, nil]
                return \(raw: chain)
            }()
            """
    }

    private static func isBoolOptional(_ type: TypeSyntax) -> Bool {
        if let optional = type.as(OptionalTypeSyntax.self),
            let identifier = optional.wrappedType.as(IdentifierTypeSyntax.self),
            identifier.name.text == "Bool"
        {
            return true
        }
        if let identifier = type.as(IdentifierTypeSyntax.self),
            identifier.name.text == "Optional",
            let genericArgs = identifier.genericArgumentClause,
            genericArgs.arguments.count == 1,
            let inner = genericArgs.arguments.first?.argument.as(IdentifierTypeSyntax.self),
            inner.name.text == "Bool"
        {
            return true
        }
        return false
    }

    private static func buildChain(
        properties: [SplatMacro.PropertyInfo],
        structName: String
    ) -> String {
        let n = properties.count
        let args = properties.enumerated().map { i, prop in
            "\(splatArgumentLabel(prop.name)): v\(i)"
        }.joined(separator: ", ")
        let initCall = "\(structName)(\(args))"

        var lines: [String] = []

        for i in 0..<n {
            let nest = String(repeating: "    ", count: i)
            let op = i < n - 1 ? "flatMap" : "map"
            lines.append("\(nest)_v.\(op) { v\(i) in")
        }

        let deepIndent = String(repeating: "    ", count: n)
        lines.append("\(deepIndent)\(initCall)")

        for i in stride(from: n - 1, through: 0, by: -1) {
            let nest = String(repeating: "    ", count: i)
            lines.append("\(nest)}")
        }

        return lines.joined(separator: "\n")
    }
}

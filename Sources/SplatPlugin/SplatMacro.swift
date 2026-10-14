import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

func splatArgumentLabel(_ name: String) -> String {
    let bare: String =
        (name.hasPrefix("`") && name.hasSuffix("`") && name.count >= 2)
        ? String(name.dropFirst().dropLast())
        : name
    guard let first = bare.first else { return "`\(name)`" }
    let isPlainIdentifier =
        (first == "_" || first.isLetter)
        && bare.dropFirst().allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
    return isPlainIdentifier ? bare : "`\(bare)`"
}

public struct SplatMacro: MemberMacro {
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

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        let structName: String
        let propertyName: String

        if case .argumentList(let arguments) = node.arguments {
            if let structArg = arguments.first(where: { $0.label?.text == "structName" }),
                let stringLiteral = structArg.expression.as(StringLiteralExprSyntax.self),
                stringLiteral.segments.count == 1,
                case .stringSegment(let segment) = stringLiteral.segments.first
            {
                structName = segment.content.text
            } else {
                structName = "Arguments"
            }

            if let propArg = arguments.first(where: { $0.label?.text == "propertyName" }),
                let stringLiteral = propArg.expression.as(StringLiteralExprSyntax.self),
                stringLiteral.segments.count == 1,
                case .stringSegment(let segment) = stringLiteral.segments.first
            {
                propertyName = segment.content.text
            } else {
                propertyName = "arguments"
            }
        } else {
            structName = "Arguments"
            propertyName = "arguments"
        }

        guard
            let targetStruct = declaration.memberBlock.members
                .compactMap({ $0.decl.as(StructDeclSyntax.self) })
                .first(where: { $0.name.text == structName })
        else {
            throw SplatError.noTargetStruct(structName)
        }

        func stripBackticks(_ text: String) -> String {
            if text.hasPrefix("`") && text.hasSuffix("`") && text.count > 2 {
                return String(text.dropFirst().dropLast())
            }
            return text
        }

        func trimWhitespace(_ text: String) -> String {
            var result = text
            while result.first?.isWhitespace == true {
                result.removeFirst()
            }
            while result.last?.isWhitespace == true {
                result.removeLast()
            }
            return result
        }

        func collectProperties(
            from targetStruct: StructDeclSyntax,
            in declaration: some DeclGroupSyntax,
            path: [String] = []
        ) -> [PropertyInfo] {
            let explicitInits = targetStruct.memberBlock.members
                .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

            if let firstInit = explicitInits.first,
                firstInit.signature.parameterClause.parameters.isEmpty
            {
                return []
            }

            let defaultsByName: [String: InitializerClauseSyntax] = {
                guard let firstInit = explicitInits.first else { return [:] }
                var defaults: [String: InitializerClauseSyntax] = [:]
                for param in firstInit.signature.parameterClause.parameters {
                    guard let defaultValue = param.defaultValue else { continue }
                    let name = stripBackticks(param.firstName.text)
                    defaults[name] = defaultValue
                }
                return defaults
            }()

            let directProperties = targetStruct.memberBlock.members
                .compactMap { $0.decl.as(VariableDeclSyntax.self) }
                .filter { $0.bindings.first?.accessorBlock == nil }
                .flatMap { variable -> [PropertyInfo] in
                    let docComment = extractDocComment(from: variable)
                    return variable.bindings.compactMap { binding in
                        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                            let type = binding.typeAnnotation?.type
                        else {
                            return nil
                        }
                        let name = stripBackticks(identifier.identifier.text)
                        return PropertyInfo(
                            name: name,
                            type: type,
                            doc: docComment,
                            path: path,
                            defaultValue: defaultsByName[name]
                        )
                    }
                }

            var allProperties: [PropertyInfo] = []

            for property in directProperties {
                let typeString = property.type.trimmed.description

                if typeString.hasSuffix(".Arguments") {
                    var parentTypeName = typeString
                    if parentTypeName.hasSuffix(".Arguments") {
                        parentTypeName = String(parentTypeName.dropLast(".Arguments".count))
                    }
                    parentTypeName = parentTypeName.trimmingCharacters(
                        in: CharacterSet(charactersIn: "`")
                    )

                    if let nestedStruct = declaration.memberBlock.members
                        .compactMap({ $0.decl.as(StructDeclSyntax.self) })
                        .first(where: { stripBackticks($0.name.text) == parentTypeName }),
                        let nestedArgumentsStruct = nestedStruct.memberBlock.members
                            .compactMap({ $0.decl.as(StructDeclSyntax.self) })
                            .first(where: { $0.name.text == "Arguments" })
                    {
                        let nestedPath = path + [property.name]
                        let nestedProperties = collectProperties(
                            from: nestedArgumentsStruct,
                            in: declaration,
                            path: nestedPath
                        )
                        allProperties.append(contentsOf: nestedProperties)
                    } else {
                        allProperties.append(property)
                    }
                } else {
                    allProperties.append(property)
                }
            }

            return allProperties
        }

        func extractDocComment(from variable: VariableDeclSyntax) -> String? {
            let trivia = variable.leadingTrivia
            var docLines: [String] = []

            for piece in trivia {
                switch piece {
                case .docLineComment(let text):
                    let cleaned = trimWhitespace(text.trimmingPrefix("///"))
                    docLines.append(cleaned)

                case .docBlockComment(let text):
                    let lines =
                        text
                        .trimmingPrefix("/**")
                        .trimmingSuffix("*/")
                        .split(separator: "\n")
                        .map { line -> String in
                            let trimmed = trimWhitespace(String(line))
                            return trimWhitespace(trimmed.trimmingPrefix("*"))
                        }
                    docLines.append(contentsOf: lines)

                default:
                    break
                }
            }

            return docLines.isEmpty ? nil : docLines.joined(separator: "\n///     ")
        }

        let properties = collectProperties(from: targetStruct, in: declaration)

        let allStoredProperties = declaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { $0.bindings.first?.accessorBlock == nil }

        let hasOutputProperties = allStoredProperties.contains { variable in
            variable.bindings.contains { binding in
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    return false
                }
                let name = stripBackticks(identifier.identifier.text)
                return name != propertyName
            }
        }

        let discardableResultAttr = hasOutputProperties ? "" : "@discardableResult\n"

        let hasThrowingParentInit = declaration.memberBlock.members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }
            .contains { initializer in
                initializer.signature.effectSpecifiers?.throwsClause != nil
            }

        let hasThrowingArgumentsInit = targetStruct.memberBlock.members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }
            .contains { initializer in
                initializer.signature.effectSpecifiers?.throwsClause != nil
            }

        let hasThrowingInit = hasThrowingParentInit || hasThrowingArgumentsInit

        let simpleThrowsClause: String
        let simpleTryKeyword: String
        if hasThrowingInit {
            if let errorType = declaration.memberBlock.members
                .compactMap({ $0.decl.as(InitializerDeclSyntax.self) })
                .first(where: { $0.signature.effectSpecifiers?.throwsClause != nil })?
                .signature.effectSpecifiers?.throwsClause?.type
            {
                simpleThrowsClause = "throws(Self.\(errorType.trimmed)) "
            } else {
                simpleThrowsClause = "throws "
            }
            simpleTryKeyword = "try "
        } else {
            simpleThrowsClause = ""
            simpleTryKeyword = ""
        }

        guard !properties.isEmpty else {
            let summaryDoc = """
                /// Initializer that creates a ``\(structName)`` instance with default values.
                """

            let simpleInit: DeclSyntax = """
                \(raw: discardableResultAttr)\(raw: summaryDoc)
                public init() \(raw: simpleThrowsClause){
                    \(raw: simpleTryKeyword)self.init(\(raw: structName)())
                }
                """

            return [simpleInit]
        }

        let parameters = properties.map { property in
            FunctionParameterSyntax(
                firstName: .identifier("`\(property.name)`"),
                type: property.type,
                defaultValue: property.defaultValue
            )
        }

        func buildArgumentsInit(properties: [PropertyInfo]) -> String {
            let allDirect = properties.allSatisfy { $0.path.isEmpty }

            if allDirect {
                return properties.map { "\(splatArgumentLabel($0.name)): `\($0.name)`" }.joined(
                    separator: ", "
                )
            }

            let grouped = Dictionary(grouping: properties) { $0.path.first }

            return grouped.sorted { a, b in
                guard let aKey = a.key else { return true }
                guard let bKey = b.key else { return false }
                return aKey < bKey
            }.map { key, props -> String in
                if let pathComponent = key {
                    let nestedProps = props.map { prop in
                        PropertyInfo(
                            name: prop.name,
                            type: prop.type,
                            doc: prop.doc,
                            path: Array(prop.path.dropFirst()),
                            defaultValue: prop.defaultValue
                        )
                    }
                    let nestedInit = buildArgumentsInit(properties: nestedProps)
                    return "\(splatArgumentLabel(pathComponent)): .init(\(nestedInit))"
                } else {
                    return props.map { "\(splatArgumentLabel($0.name)): `\($0.name)`" }.joined(
                        separator: ", "
                    )
                }
            }.joined(separator: ",\n        ")
        }

        let argumentsCallArgs = buildArgumentsInit(properties: properties)

        let throwsClause: String
        if hasThrowingInit {
            if let errorType = declaration.memberBlock.members
                .compactMap({ $0.decl.as(InitializerDeclSyntax.self) })
                .first(where: { $0.signature.effectSpecifiers?.throwsClause != nil })?
                .signature.effectSpecifiers?.throwsClause?.type
            {
                throwsClause = "throws(Self.\(errorType.trimmed))"
            } else {
                throwsClause = "throws"
            }
        } else {
            throwsClause = ""
        }

        let tryKeyword = hasThrowingInit ? "try " : ""

        let (argumentsInitDoc, argumentsParamDocs): (String?, [String: String]) = {
            let inits = targetStruct.memberBlock.members
                .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

            guard let firstInit = inits.first else { return (nil, [:]) }

            let trivia = firstInit.leadingTrivia
            var docLines: [String] = []

            for piece in trivia {
                switch piece {
                case .docLineComment(let text):
                    let cleaned = trimWhitespace(text.trimmingPrefix("///"))
                    docLines.append(cleaned)

                case .docBlockComment(let text):
                    let lines =
                        text
                        .trimmingPrefix("/**")
                        .trimmingSuffix("*/")
                        .split(separator: "\n")
                        .map { line -> String in
                            let trimmed = trimWhitespace(String(line))
                            return trimWhitespace(trimmed.trimmingPrefix("*"))
                        }
                    docLines.append(contentsOf: lines)

                default:
                    break
                }
            }

            guard let paramIndex = docLines.firstIndex(where: { $0.hasPrefix("- Parameters:") })
            else {
                return (docLines.isEmpty ? nil : docLines.joined(separator: "\n/// "), [:])
            }

            let summaryLines = Array(docLines[..<paramIndex])
            let summary = summaryLines.isEmpty ? nil : summaryLines.joined(separator: "\n/// ")

            var paramDocs: [String: String] = [:]
            var currentParam: String?
            var currentParamLines: [String] = []

            for line in docLines[(paramIndex + 1)...] {
                if line.hasPrefix("- ") {
                    if let param = currentParam {
                        paramDocs[param] = currentParamLines.joined(separator: "\n///     ")
                    }
                    let parts = line.dropFirst(2).split(separator: ":", maxSplits: 1)
                    if parts.count == 2 {
                        currentParam = trimWhitespace(String(parts[0]))
                        currentParamLines = [trimWhitespace(String(parts[1]))]
                    }
                } else {
                    currentParamLines.append(line)
                }
            }

            if let param = currentParam {
                paramDocs[param] = currentParamLines.joined(separator: "\n///     ")
            }

            return (summary, paramDocs)
        }()

        let parameterDocs = properties.map { property in
            if let doc = argumentsParamDocs[property.name] {
                return "///   - \(property.name): \(doc)"
            } else if let doc = property.doc {
                return "///   - \(property.name): \(doc)"
            } else {
                return "///   - \(property.name): \(property.type.trimmed)"
            }
        }.joined(separator: "\n")

        let throwsDocs: String = {
            if !hasThrowingInit {
                return ""
            }

            let parentInits = declaration.memberBlock.members
                .compactMap { $0.decl.as(InitializerDeclSyntax.self) }

            for parentInit in parentInits {
                guard parentInit.signature.effectSpecifiers?.throwsClause != nil else {
                    continue
                }

                let trivia = parentInit.leadingTrivia
                var docLines: [String] = []

                for piece in trivia {
                    switch piece {
                    case .docLineComment(let text):
                        let cleaned = trimWhitespace(text.trimmingPrefix("///"))
                        docLines.append(cleaned)

                    case .docBlockComment(let text):
                        let lines =
                            text
                            .trimmingPrefix("/**")
                            .trimmingSuffix("*/")
                            .split(separator: "\n")
                            .map { line -> String in
                                let trimmed = trimWhitespace(String(line))
                                return trimWhitespace(trimmed.trimmingPrefix("*"))
                            }
                        docLines.append(contentsOf: lines)

                    default:
                        break
                    }
                }

                for line in docLines where line.hasPrefix("- Throws:") {
                    let throwsText = trimWhitespace(String(line.dropFirst("- Throws:".count)))
                    return "\n/// - Throws: \(throwsText)"
                }
            }

            return "\n/// - Throws: Error if initialization fails."
        }()

        let summaryDoc: String
        if let initDoc = argumentsInitDoc {
            summaryDoc = "/// \(initDoc)"
        } else {
            summaryDoc = """
                /// Initializer accepting ``\(structName)`` properties as individual parameters.
                ///
                /// This initializer provides direct parameter access without explicitly creating
                /// a ``\(structName)`` instance.
                """
        }

        let initializer: DeclSyntax = """
            \(raw: discardableResultAttr)\(raw: summaryDoc)
            ///
            /// - Parameters:
            \(raw: parameterDocs)\(raw: throwsDocs)
            public init(
                \(raw: parameters.map { "\($0)" }.joined(separator: ",\n    "))
            ) \(raw: throwsClause) {
                \(raw: tryKeyword)self.init(\(raw: structName)(
                    \(raw: argumentsCallArgs)
                ))
            }
            """

        var declarations: [DeclSyntax] = [initializer]
        if let allCases = ExhaustiveCases.generate(properties: properties, structName: structName) {
            declarations.append(allCases)
        }
        return declarations
    }
}

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

extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    func trimmingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}

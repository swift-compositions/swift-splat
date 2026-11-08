import Splat

@Splat
public struct TypedThrowsFixture: Sendable {
    public let arguments: Arguments

    public init(_ arguments: Arguments) throws(Error) {
        guard arguments.isValid else {
            throw Error(reason: "Validation failed: isValid was false")
        }
        self.arguments = arguments
    }

    public struct Arguments: Sendable {
        public let isValid: Bool

        public init(isValid: Bool) {
            self.isValid = isValid
        }
    }

    public struct Error: Swift::Error, Sendable {
        public let reason: String

        public init(reason: String) {
            self.reason = reason
        }
    }
}


extension RegularNamespace {
}

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

public enum RegularNamespace {
    public enum Three10 {
        @Splat
        public struct One: Sendable {
            public let arguments: Arguments
            public let output: Output

            public enum Output: Sendable, Equatable {
                case valid
                case invalid
            }

            public init(_ arguments: Arguments) {
                self.arguments = arguments
                self.output = arguments.conditionSatisfied == true ? .valid : .invalid
            }

            public struct Arguments: Sendable {
                public let conditionSatisfied: Bool?

                public init(conditionSatisfied: Bool? = nil) {
                    self.conditionSatisfied = conditionSatisfied
                }
            }
        }
    }
}

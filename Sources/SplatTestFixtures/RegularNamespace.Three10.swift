import Splat


extension RegularNamespace {
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

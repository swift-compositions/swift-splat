# swift-splat

Use this package when a type takes a nested arguments struct in its initializer, for validation or to keep the inputs, and you also want callers to pass those fields as plain parameters. Attach `@Splat` to the type. It generates a public initializer with one parameter per field that builds the arguments struct and calls your initializer with it.

## Laws

- The arguments struct is the nested struct named `structName`, `Arguments` by default. If there is none, the type doesn't compile. `propertyName` doesn't choose the struct. It only marks which stored property holds it.
- Parameters are the struct's stored properties that have a type annotation, in declaration order. Computed properties and properties without a type annotation are skipped.
- A parameter keeps the default value of the matching parameter in the struct's first explicit initializer. If that initializer takes no parameters, the generated initializer takes none either.
- A field whose type is the `Arguments` of another struct nested in the same type, such as `Lid1.Arguments`, is flattened. Its fields become parameters in its place, and the macro rebuilds the nested struct for you.
- The generated initializer throws if any initializer of the type or of the arguments struct throws. It uses the typed error of the type's first throwing initializer, written as `Self.` followed by that error type, so the typed error survives across modules. A typed error thrown only by the arguments struct's initializer becomes an untyped `throws`.
- When the type has no stored property other than `propertyName`, the generated initializer is `@discardableResult`.
- A field named with backticks and spaces stays a backticked parameter label.
- When every field is a direct `Bool?`, the macro also generates `allCases`: every combination of true, false and nil, 3 to the power of the field count.
- Doc comments carry over. The arguments struct initializer's summary and parameter docs win over each field's own doc comment, and the field's type is used when neither exists. A `- Throws:` line from the type's throwing initializer is copied too.

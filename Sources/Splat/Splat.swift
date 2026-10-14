@attached(member, names: arbitrary)
public macro Splat(
    propertyName: String = "arguments",
    structName: String = "Arguments"
) = #externalMacro(module: "SplatPlugin", type: "SplatMacro")

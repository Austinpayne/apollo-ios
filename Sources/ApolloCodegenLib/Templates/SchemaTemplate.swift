import Foundation
import ApolloUtils

/// Provides the format to define a schema in Swift code. The schema represents metadata used by
/// the GraphQL executor at runtime to convert response data into corresponding Swift types.
struct SchemaTemplate: TemplateRenderer {
  // IR representation of source GraphQL schema.
  let schema: IR.Schema

  /// Shared codegen configuration.
  let config: ReferenceWrapped<ApolloCodegenConfiguration>

  let schemaName: String

  var target: TemplateTarget = .schemaFile

  var template: TemplateString { embeddableTemplate }

  /// Swift code that can be embedded within a namespace.
  var embeddableTemplate: TemplateString {
    TemplateString(
    """
    public typealias ID = String

    \(if: !config.output.schemaTypes.isInModule,
      TemplateString("""
      public typealias SelectionSet = \(schemaName)_SelectionSet

      public typealias InlineFragment = \(schemaName)_InlineFragment
      """),
    else: protocolDefinition(prefix: nil, schemaName: schemaName))

    public enum Schema: SchemaConfiguration {
      public static func objectType(forTypename __typename: String) -> Object.Type? {
        switch __typename {
        \(schema.referencedTypes.objects.map {
          "case \"\($0.name.firstUppercased)\": return \(schemaName).\($0.name.firstUppercased).self"
        }, separator: "\n")
        default: return nil
        }
      }
    }
    """
    )
  }

  /// Swift code that must be rendered outside of any namespace.
  var detachedTemplate: TemplateString? {
    guard !config.output.schemaTypes.isInModule else { return nil }

    return protocolDefinition(prefix: "\(schemaName)_", schemaName: schemaName)
  }

  init(schema: IR.Schema, config: ReferenceWrapped<ApolloCodegenConfiguration>) {
    self.schema = schema
    self.schemaName = schema.name.firstUppercased
    self.config = config
  }

  private func protocolDefinition(prefix: String?, schemaName: String) -> TemplateString {
    TemplateString("""
      public protocol \(prefix ?? "")SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
      where Schema == \(schemaName).Schema {}

      public protocol \(prefix ?? "")InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
      where Schema == \(schemaName).Schema {}
      """
    )
  }
}

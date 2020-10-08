# Lucid - Setup

Before getting started, make sure to take a look at [how to install Lucid](Installation.md) first.

Because Lucid is using code generation to link all its pieces together, it requires a specific structure in order to work properly.

## [Configuration File](../CodeGen/Sources/LucidCommand/CommandConfiguration.swift)

The configuration file is a YAML file usually named `.lucid.yaml` and stored at the root of the project. Naming it differently requires to use the option `--config-path` when running the command `lucid swift`.

Here is what a basic configuration file looks like:

```yaml
input_path: Descriptions
targets:
  app:
    module_name: App
    output_path: App/Generated
```

After running the command `lucid swift` with this configuration, the directory `App/Generated` contains all of the generated code corresponding to whichever JSON description files were placed in the `Descriptions` directory.

### Fields

- `input_path`: Path to a directory containing the entity/subtype/payload description files (required).
- `targets`:
	- `app`/`app_test`/`app_test_support`:
		- `module_name`: Module name for this target (optional).
		- `output_path`: Path to directory which contains the generated code for this target (optional). 
- `active_targets`: List of targets which should be generated (defaults to `app`).
- `extensions_path`: Path to a directory containing the [extensions](CommandExtensions.md) (optional).
- `cache_path`: Path to the cache directory (defaults to `/usr/local/share/lucid/cache`).
- `organization_name`: Name of your organization (optional).
- `current_version`: Current version of the application (defaults to `1.0.0`).
- `git_remote`: URL pointing to your project's git remote (defaults to `$(git remote get-url origin)`).
- `force_build_new_db_model`: Forces to re-generate a new database model for every version of the application (defaults to `true`). When set to `false`, Lucid requires the application to follow a [standard git versioning](CoreData.md) using one tag per version. 
- `force_build_new_db_model_for_versions`: List of versions of the application for which a new database model should always be generated (optional).
- `response_handler_function`: Name of the function handling repsonses from the main [client queue](Client.md) (optional)
- `core_data_migrations_function`: Name of the function handling [core data heavy migrations](CoreData.md) (optional).
- `lexicon`: List of words which should not be altered when from/to camel case/snake case  (optional).
- `entity_suffix`: A suffix added to the generated entity names (optional). 

## Description Files

Lucid reads three types of description files; entities, subtypes and endpoint payloads. These files need to be placed in their respective directories, at the path specified with the `input_path` field of the configuration file.

The file structure should look like the following:

```bash
$ tree
.
└── Descriptions
    ├── EndpointPayloads
    │   └── MyEntity.json
    ├── Entities
    │   └── MyEntity.json
    └── Subtypes
        └── MySubtype.json
```

Note that any file structure can be used under `Entities`, `Subtypes`, `EndpointPayloads` as soon as there isn't any conflicting names.

### [Entity Description](../)

An entity is an object which holds data related to a specific part of a business. Entities can relate to each other, with either one to one or one to many relationships. They can also use scalar types (int, string, bool, ...) or subtypes to describe the data they contain.

Here is what a basic entity looks like:

```json
{
  "name": "my_entity",
  "versionHistory": [{
    "version" : "1.0.0"
  }],
  "persist": true,
  "identifier": {
    "type": "int"
  }
  "properties": [{
    "name" : "my_string_property",
    "propertyType" : "string"
  }, {
    "name" : "my_bool_property",
    "propertyType" : "bool"
  }]
}
```

#### Fields

- `name`: Entity name (required).
- `identifier`: [Identifier description](Setup.md#entity-identifier-description) (required).
- `properties`: [Property descriptions](Setup.md#entity-property-description) (required).
- `metadata`: [Metadata property descriptions](Setup.md#entity-metadata-description) (optional).
- `system_properties`: [List of built-in property names](Setup.md#system-properties) (optional).
- `version_history`: [Version history description](Setup.md#entity-version-history) (required). Initially, the current version should be used.
- `remote`: Weither this entity can be read/written from/to a server (defaults to `true`).
- `persist`: Weither this entity should be persisted (defaults to `false`).
- `persisted_name`: Entity name used for persisting (defaults to `$name`).
- `platforms`: Platforms for which the code should be generated (optional).
- `client_queue_name`: Name of the designated client queue for this entity (defaults to `main`).

### Entity Identifier Description

Every entity has a unique identifier which is used to refer to it when using queries. 

There are three ways to declare an identifier:

1. Using a property.

	```json
	"identifier": {
	  "type": "property",
	  "property_name": "$property_name"
	}
	```
	
2. Using a scalar type.

	```json
	"identifier": {
	  "type": "$scalar_type"
	}
	```
	
3. By derivating it from a set of relationships.

	```json
	"identifier": {
	  "type": "$scalar_type",
	  "derived_from_relationships": ["$entity_name"]
	}
	```
	
	When using this method, the scalar type must match the relationships identifier scalar type. 
	
	This is mostly used when two or more entities are able to share an identifier. When used, Lucid generates some additional conversion methods necessary to convert identifiers from one entity type to another.


### Entity Property Description

A property is a named value stored as part of an entity object. For every property, Lucid generates an index which can be used inside of queries in order to accurately select data.

#### Fields

- `name`: Property name (required).
- `previous_name`: Previously used name for that property (optional). Used for local data model light migrations.
- `added_at_version`: Version at which an entity was added (defaults to `$initial_version`). When using a local data model, this field is used for testing migrations between versions.
- `property_type`: [Property type description](Setup.md#entity-property-type-description) (required).
- `key`: Key to use for parsing from a JSON payload (defaults to `$name`).
- `match_exact_key`: When set to `false`, prevent Lucid from automatically appending `id` or `ids` to property keys which are declared as relationships (defaults to `false`).
- `nullable`: Weither this property can be `nil` (defaults to `false`).
- `default_value`: Value the property automatically takes when it hasn't a defined value (optional).
- `log_error`: Weither Lucid should log non fatal conversion errors (defaults to `true`).
- `use_for_equality`: Weither this property should be used when testing for equality (defaults to `true`).
- `mutable`: Weither this property can be mutated locally (defaults to `false`).
- `objc`: Weither this property must be accessible to ObjC (defaults to `false`).
- `unused`: Weither this property should be included in the generated code (defaults to `false`).
- `lazy`: Weither this property is lazy (defaults to `false`).
- `platforms`: Platforms for which the code should be generated (optional).
- `persisted_name`: Property name used for persistence (defaults to `$name`).

#### Lazy Properties

Lazy properties are a way to workaround inconsistencies there might be the data model. Most of the time, these happens when a endpoint serves a set of properties but another endpoint serves a different set or properties for the same entity.

Lazy properties can take two values:

```swift
enum Lazy<T> {
    case requested(T)
    case unrequested
}
```

Because an unrequested lazy property cannot override a requested one, payloads' inconsistencies cannot harm the consistence of the local stores.

#### Mutable Properties

A mutable property can be set locally and pushed to local and/or remote stores. As soon as an entity has at least one mutable property, Lucid will generate a public initializer so that users can create them from scratch, allowing for the property mutation to happen. It will also generate the convenience method `updated` to easily copy the entity with the given mutated properties.

Since entities are expressed as Swift immutable objects, a mutated entity is always a copy of another non-mutated entity. To save changes made to a mutable entity, you must set it with its designated [CoreManager](../Lucid/Core/CoreManager.swift).

### Entity Property Type Description

Property types can be of three categories:

1. [Scalar](Setup.md#property-scalar-types), which are built-in types.

	```json
	"property_type": "$scalar_type"
	```

2. [Subtype](Setup.md#subtype-description), which refers to a user-defined scalar type.

	```json
	"property_type": "$subtype_name"
	```

3. Relationship, which refers to another entity type.

	```json
	"property_type": {
	  "entity_name": "$entity_name",
	  "association": "$association",
	  ...
	}
	``` 
	- `entity_name`: Entity type which this relationship refers to (required).
	- `association`: Type of association (required). Can be either `one_to_one` or `one_to_many`.
	- `id_only`: Weither this relationship is expected to be expressed as a nested object (defaults to `false`). When `true`, Lucid automatically appends `id` or `ids` (depending on the association type) to the parsing key, unless `match_exact_key` is `true`.
	- `failable_items`: Weither this relationship is allowed to fail to parse as a nested object (defaults to `true`).
	- `platforms`: Platforms for which the code should be generated (optional).

### Property Scalar Types

A scalar type is a built-in type which can be referred to using any of the following names:

```
enum PropertyScalarType {
    case string
    case int
    case date
    case double
    case float
    case bool
    case seconds
    case milliseconds
    case url
    case color
}
```

### System Properties

A system property is a built-in property which comes with features Lucid can only implement at its core.

- `last_remote_read`: Property set to the last date at which this property was pulled from a remote store.
- `is_synced`: Weither the concerned entity is in sync with the remote store(s). Only applicable for mutable entities.

### Entity Metadata Description



### Entity Version History


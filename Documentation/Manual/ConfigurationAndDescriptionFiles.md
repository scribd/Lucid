# Lucid - Configuration And Description Files

Because Lucid is using code generation to link everything together, the configuration and description files must be configured correctly to generate the proper code for your project.

## [Configuration File](../CodeGen/Sources/LucidCommand/CommandConfiguration.swift)

The configuration file is a YAML file usually named `.lucid.yaml` and is stored at the root of the project. To use a custom filename, you must use the option `--config-path` when running the command `lucid swift`.

Here is a basic configuration file:

```yaml
input_path: Descriptions
targets:
  app:
    module_name: App
    output_path: App/Generated
```

After running the command `lucid swift` with this configuration, the directory `App/Generated` contains all of the generated code corresponding to the JSON description files placed in the `Descriptions` directory.

### Fields

- `input_path`: Path to a directory containing the entity/subtype/payload description files ***(required)***.
- `targets`:
	- `app`/`app_test`/`app_test_support`:
		- `module_name`: Module name for this target ***(optional)***.
		- `output_path`: Path to directory which contains the generated code for this target ***(optional)***. 
- `active_targets`: List of targets which should be generated ***(defaults to `app`)***.
- `extensions_path`: Path to a directory containing the [extensions](CommandExtensions.md) ***(optional)***.
- `cache_path`: Path to the cache directory ***(defaults to `/usr/local/share/lucid/cache`)***.
- `organization_name`: Name of your organization ***(optional)***.
- `current_version`: Current version of the application ***(defaults to `1.0.0`)***.
- `git_remote`: URL pointing to your project's git remote ***(defaults to `$(git remote get-url origin)`)***.
- `force_build_new_db_model`: Forces to re-generate a new database model for every version of the application ***(defaults to `true`)***. When set to `false`, Lucid requires the application to follow a [standard git versioning](CoreData.md) using one tag per version. 
- `force_build_new_db_model_for_versions`: List of versions of the application for which a new database model should always be generated ***(optional)***.
- `response_handler_function`: Name of the function handling repsonses from the main [client queue](Client.md) ***(optional)***
- `core_data_migrations_function`: Name of the function handling [core data heavy migrations](CoreData.md) ***(optional)***.
- `lexicon`: List of words which should not be altered when to/from camel case/snake case  ***(optional)***.
- `entity_suffix`: A suffix added to the generated entity names ***(optional)***. 

## Description Files

Lucid reads three types of description files: entities, subtypes, and endpoint payloads. These files need to be placed in their respective directories, at the path specified with the `input_path` field of the configuration file.

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

Note that any subdirectory structure can be used under `Entities`, `Subtypes`, `EndpointPayloads` as long as there aren't any conflicting names.

### Entity Description

An entity is an object which holds data related to a specific part of a business. Entities can relate to each other, with either one-to-one or one-to-many relationships. They can also use scalar types (int, string, bool, ...) or subtypes to describe the data they contain.

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

- `name`: Entity name ***(required)***.
- `identifier`: [Identifier description](ConfigurationAndDescriptionFiles.md#entity-identifier-description) ***(required)***.
- `properties`: [Property descriptions](ConfigurationAndDescriptionFiles.md#entity-property-description) ***(required)***.
- `metadata`: [Metadata property descriptions](ConfigurationAndDescriptionFiles.md#metadata-description) ***(optional)***.
- `system_properties`: [List of built-in property names](ConfigurationAndDescriptionFiles.md#system-properties) ***(optional)***.
- `version_history`: [Version history description](ConfigurationAndDescriptionFiles.md#entity-version-history) ***(required)***. Initially, the current version should be used.
- `remote`: Whether or not this entity can be read/written to/from a server ***(defaults to `true`)***.
- `persist`: Whether or not this entity should be persisted ***(defaults to `false`)***.
- `persisted_name`: Entity name used for persisting ***(defaults to `$name`)***.
- `platforms`: Platforms for which the code should be generated ***(optional)***.
- `client_queue_name`: Name of the designated client queue for this entity ***(defaults to `main`)***.

### Entity Identifier Description

Every entity has a unique identifier which is used to refer to it when using queries. 

There are three ways to declare an identifier:

1. Using a scalar type.

	```json
	"identifier": {
	  "type": "$scalar_type"
	}
	```
e.g. If you use `int`, your JSON payload must contain the field "id: \<int value>"

2. Using a property.

	```json
	"identifier": {
	  "type": "property",
	  "property_name": "$property_name"
	}
	```
*Note: property values must be unique, such as an email address, or else records can overwrite each other.*
	
		
3. By deriving it from a set of relationships.

	```json
	"identifier": {
	  "type": "$scalar_type",
	  "derived_from_relationships": ["$entity_name"]
	}
	```
	
	When using this method, the scalar type must match the relationship's identifier scalar type. 
	
	This is mostly used when two or more entities are able to share an identifier. When used, Lucid generates some additional conversion methods necessary to convert identifiers from one entity type to another.

#### Identifier Key

By default the identifier is parsed on the key `"id"`. To set a custom key name, you can also set the property `"key"` in your description. e.g.:

```json
"identifier": {
  "key": "remote_id",
  "type": "int"
}
```

### Entity Property Description

A property is a named value stored as part of an entity object. For every property, Lucid generates an index which can be used inside queries in order to accurately select data.

#### Fields

- `name`: Property name ***(required)***.
- `previous_name`: Previously used name for that property ***(optional)***. Used for local data model light migrations.
- `added_at_version`: Version at which an entity was added ***(defaults to `$initial_version`)***. When using a local data model, this field is used for testing migrations between versions.
- `property_type`: [Property type description](ConfigurationAndDescriptionFiles.md#entity-property-type-description) ***(required)***.
- `key`: Key to use for parsing from a JSON payload ***(defaults to `$name`)***.
- `match_exact_key`: When set to `false`, prevent Lucid from automatically appending `id` or `ids` to property keys which are declared as relationships ***(defaults to `false`)***.
- `nullable`: Whether or not this property can be `nil` ***(defaults to `false`)***.
- `default_value`: Value the property automatically takes when it hasn't a defined value ***(optional)***.
- `log_error`: Whether or not Lucid should log non fatal conversion errors ***(defaults to `true`)***.
- `use_for_equality`: Whether or not this property should be used when testing for equality ***(defaults to `true`)***.
- `mutable`: Whether or not this property can be mutated locally ***(defaults to `false`)***.
- `objc`: Whether or not this property must be accessible to ObjC ***(defaults to `false`)***.
- `unused`: Whether or not this property should be included in the generated code ***(defaults to `false`)***.
- `lazy`: Whether or not this property is lazy ***(defaults to `false`)***.
- `platforms`: Platforms for which the code should be generated ***(optional)***.
- `persisted_name`: Property name used for persistence ***(defaults to `$name`)***.

#### Lazy Properties

Lazy properties are a way to work around an overloaded object or inconsistencies in the data model. Most of the time, these happens when an endpoint serves a set of properties but another endpoint serves a different set or properties for the same entity.

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

### System Properties

A system property is a built-in property which comes with features Lucid can only implement at its core.

- `last_remote_read`: Property set to the last date at which this property was pulled from a remote store.
- `is_synced`: Whether or not the concerned entity is in sync with the remote store(s). Only applicable for mutable entities.

### Entity Property Type Description

Property types can be of three categories:

1. [Scalar](ConfigurationAndDescriptionFiles.md#property-scalar-types), which are built-in types.

	```json
	"property_type": "$scalar_type"
	```

2. [Subtype](ConfigurationAndDescriptionFiles.md#subtype-description), which refers to a user-defined scalar type.

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
	- `entity_name`: Entity type which this relationship refers to ***(required)***.
	- `association`: Type of association ***(required)***. Can be either `one_to_one` or `one_to_many`.
	- `id_only`: Whether or not this relationship is expected to be expressed as a nested object ***(defaults to `false`)***. When `true`, Lucid automatically appends `id` or `ids` (depending on the association type) to the parsing key, unless `match_exact_key` is `true`.
	- `failable_items`: Whether or not this relationship is allowed to fail to parse as a nested object ***(defaults to `true`)***. When set to `true`, lucid will still attempt to capture the identifier of the failed relationship.
	- `platforms`: Platforms for which the code should be generated ***(optional)***.

### Entity Version History

The version history is a way to keep track of versions which need local heavy migrations as opposed to light migrations, which can implicitly applied.

For every item in the version history, Lucid generates a data model for that entity (e.g. `MyEntity_1.0.0`). These models can then be used to write migrations in plain code.

#### Fields

- `version`: Version number ***(required)***, Supports major, minor, and optional patch (e.g. ***5.2*** and ***5.2.1*** are both valid). Initially, every entity uses the current version at which they were added.
- `previous_name`: In case the entity has been renamed, this field contains the name previously used for this version ***(optional)***.
- `ignore_migration_checks`: Whether or not the migrations tests should ignore this version ***(defaults to `false`)***.
- `ignore_property_migration_checks_on`: List of property which for which the migrations tests should ignore this version ***(optional)***.

### Subtype Description

Subtypes are types which cannot refer to entities. It can be seen as user-defined scalar types.

Here is what a basic subtype looks like:

- Enum:

	```json
	{
	  "name": "my_subtype",
	  "cases": ["my_case_one", "my_case_two"]
	}
	```
	
- Optionset:

	```json
	{
	  "name": "my_subtype",
	  "options": ["my_option_one", "my_option_two"]
	}
	```
	
- Struct:

	```json
	{
	  "name": "my_subtype",
	  "properties": [{
	    "name": "my_bool_property",
	    "property_type": "bool"
	  }, {
	    "name": "my_string_property",
	    "property_type": "string"	  	
	  }]
	}
	```

#### Fields

- `name`: Subtype name ***(required)***.
- `manual_implementations`: List of protocols (e.g. `codable`) which should be left unimplemented by Lucid ***(optional)***.
- `platforms`: Platforms for which the code should be generated ***(optional)***.
- `objc`: Whether or not this subtype should be compatible with ObjC ***(defaults to `false`)***.

There are three categories of subtypes. The following fields must be added depending on the category. 

- `enum`:
	- `cases`: List of cases ***(required)***.
	- `unused_cases`: List of cases which should not be generated ***(optional)***.
	- `objc_none_case`: Whether or not this enum should include a none case for compatibility with ObjC ***(defaults to `false`)***.
	
- `optionset`:
	- `options`: List of options ***(required)***.
	- `unused_options`: List of options which should not be generated ***(optional)***.

- `struct`:
	- `properties`: List of properties ***(required)***. 

Struct properties reuse the same following fields than for entities; `name`, `key`, `property_type`, `nullable`, `objc`, `unused`, `default_value`, `log_error` and `platforms`.

A struct's property type cannot be a relationship, only a scalar type or another subtype.

### Property Scalar Types

A scalar type is a built-in type which can be referred to using any of the following names:

- `string`
- `int`
- `date`
- `double`
- `float`
- `bool`
- `seconds`
- `milliseconds`
- `url`
- `color` // e.g. `#FFF000`

Any of these types can be wrapped in brackets to form an array (e.g. `[string]`).

### Metadata Description

Metadata are additional properties which can be retrieved from the remote store(s), but aren't persisted. These values must sit alongside the entity at the same depth in the JSON data.

#### Fields

- `name`: Metadata property name ***(required)***.
- `property_type`: Either a [scalar type](ConfigurationAndDescriptionFiles.md#property-scalar-types) or [subtype](ConfigurationAndDescriptionFiles.md#subtype-description).
- `nullable`: Whether or not this property can be `nil` ***(defaults to `false`)***.

### Endpoint Payload Description

Endpoint payloads describe the structure Lucid should follow when parsing the data coming from specific remote endpoints.

Here is what a basic endpoint payload description looks like:

```json
{
  "name": "/my/endpoint",
  "base_key": "result",
  "read": {
    "entity": {
	   "entity_name": "my_entity",
	   "structure": "array"
	 }
  }
}
```

#### Types

Endpoints can have three types of paylaods:

* `read`: for fetching data, by default this will use the HTTP method `get`. (You can override this by setting the property **"http_method": "get/put/post/delete"**).
* `write`: This is only necessary if your application can create an entity locally. When you send the data to the server, this payload will be used to merge the response remote identifier with the locally created identifier so that the data is treated as a single entity. Not doing so can result in duplicate data. By default this uses the HTTP method `post` and can be overridden.
* `read_write`: You can use this payload for cases where the `read` and `write` payloads are identical and you want to generate less code. When using this payload type you cannot override the default `get` and `post` actions.



#### Fields

- `name`: Endpoint name ***(required)***.
- `base_key`: JSON key from which the payload should be parsed ***(optional)***. When `nil`, the parsing starts from the root.
- `entity`: [Endpoint payload entity description](ConfigurationAndDescriptionFiles.md#endpoint-payload-entity-description) ***(required)***.
- `excluded_paths`: JSON key paths which should not be parsed ***(optional)***.
- `metadata`: [Metadata descriptions](ConfigurationAndDescriptionFiles.md#metadata-description).

### Endpoint Payload Entity Description

#### Fields

- `entity_name`: Name of the entity type contained in the payload ***(required)***.
- `entity_key`: JSON key at which the entities should be parsed ***(optional)***. When `nil`, the parsing starts from the root.
- `structure`: Structure type which the entity payload is made of ***(required)***. Can be `single`, `array` or `nested_array`. A `nested_array` is a special case where each item in the array is a dictionary object that also contains an entity.
- `nullable`: Whether or not the entity payload can be `nil` ***(defaults to `false`)***.

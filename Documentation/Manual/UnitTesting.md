# Lucid - Unit Testing

Lucid provides a few ways of testing that your code works.

## Testing Framework

Lucid is composed of a lot of interfaces which you'd have to mock in order to test your code accordingly. 

To facilitate your testing experience, Lucid provides a separate framework for testing called **LucidTestKit**. 

For every component of Lucid, you'll find their double counterpart in that framework.

## Generated Test Support

To help stub entities while writing tests, Lucid can generate entity factories at the location of your choice.

This feature isn't turned on by default. To turn it on, you'll have to add the target `app_test_support` to your `targets` and `active_targets` in Lucid's [configuration file](./ConfigurationAndDescriptionFiles.md#configuration-file).

## Generated Tests

The major part of Lucid is automatically generated. Even though the generated code is safe to use in production as is, there can still be logical mistakes in the description files. Because Lucid generates the code based on those description files, some parts of the generated code still needs to be tested.

This feature isn't turned on by default. To turn it on, you'll have to add the target `app_test` to your `targets` and `activate_targets` in Lucid's [configuration file](./ConfigurationAndDescriptionFiles.md#configuration-file). Also note the `app_test` target depends on `app_test_support`, so you'll have to add them both if you want to use the generated tests.

**Note**: For those tests to work correctly you'll have to add the following environement variable to your test scheme in Xcode: **`LUCID_PROJECT_DIR=$PROJECT_DIR`**.

### Core Data Entity Tests

Those tests make sure that Core Data entities' read/write to disk operations work correctly.  

### Core Data Migration Tests

Those tests make sure that your database is able to migrate from any former version of the data model to its newest version.

For these tests to work, Lucid requires two things:

1. `CoreDataMigrationTests.swift` and `ExportSQLiteFile.swift` need to be imported in the project

2. `ExportSQLiteFile` has to be run for every new version of the model. It creates two files; `$ModelName_Version.sqlite` and `$ModelName_Version.sha256`. Those files are a snapshot of the database for the current model and will be used by `CoreDataMigrationTests` to make sure that it can be migrated to newer versions. Failing to version these two files as part of your project's repository will make `CoreDataMigrationTests` systematically fail.

### JSON Endpoint Payload Tests

Those tests make sure that every JSON endpoint payload can be transformed from data to a payload object.

#### Configuration

To be aware that it needs to generate a test for a given endpoint payload, Lucid needs the attribute `test` to be set in the appropriate [endpoint payload's configuration](./ConfigurationAndDescriptionFiles.md#endpoint-payload-description).

For example:

```json
{
    "name": "/my/endpoint",
    "base_key": "result",
    "entity": {
        "entity_name": "my_entity",
        "structure": "single"
    },
    "tests": [
        {
            "name": "my_test",
            "url": "https://my_server/my/endpoint?my_query_string",
            "endpoints": ["/my/endpoint"],
            "entities": [
                {
                    "name": "my_entity",
                    "count": $expected_entity_count,
                    "isTarget": true
                }
            ]
        }
    ]
}
```

#### Fetch JSON Payload Stubs

In order to work, these tests requires the endpoint payload's JSON data stubs to be stored in `$app_test_support.outpout_path/JSONPayloads`.

Because it would be tedious to create them manually, Lucid provides a command to generate them for you from the URL specified in the test's configuration.

```bash
$ lucid json-payloads --help
Usage:

    $ lucid json-payloads

Options:
    --input-path [default: .] - Description files location.
    --output-path [default: generated] - Where to generate JSON payloads.
    --auth-token [default: nil] - Authorization token.
    --endpoint [default: []] - Endpoints to fetch.
```

For example: 

```bash
$ lucid json-payloads \
    --input-path $json_descriptions_path \
    --output-path $app_test_support.outpout_path/JSONPayloads \
    --endpoint "/my/endpoint"
```
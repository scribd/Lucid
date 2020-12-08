# Lucid - Command

Lucid's command line is mostly a code generation tool. It has several commands which all generate parts of Lucid's infrastructure based on [configuration and description files](ConfigurationAndDescriptionFiles.md).

## Swift Code Generation

Once Lucid is correctly configured, making it generate the project's Swift code is fairly simple:

```bash
$ lucid swift
```

This command can take parameters which override the configuration file when there's a conflict.

### Parameters

- `--config-path`: Path to the configuration file ***(defaults to `.lucid.yaml`)***.
- `--current-version`: Current version of the application ***(defaults to `1.0.0`)***.
- `--cache-path`: Path to the cache directory ***(defaults to `/usr/local/share/lucid/cache`)***.
- `--force-build-new-db-model`: Force to build a new database model refardless of changes ***(defaults to: `true`)***.
- `--force-build-new-db-model-for-versions`: List of versions for which the database model should always be generated ***(optional)***.
- `--selected-targets`: List of targets to generate ***(optional)***. Can be one or more of `.app`, `app_test`, `.app_test_support`.

## Bootstrap

The bootstrap command can be used to create a project from scratch. Running it prompts a series of configuration questions, which, once answered results in the generation of a new configuration file and a standard files structure.

```bash
$ lucid bootstrap
```

## JSON Payload Stubs Generation

This command generates the JSON payload stub files based on the `tests` described on the endpoint payload descriptions. For every test, it fetches the specified URL and stores the JSON result in a file which Lucid can then use as a stub for testing the payload's parsing code. 

```bash
$ lucid json-payloads
```

### Parameters

- `--input-path`: Path to the description files ***(defaults to `.`)***.
- `--output-path`: Where the JSON paylaod stubs should be generated ***(defaults to `Generated`)***.
- `--auth-token`: Authorization token used for URLs which require authentication ***(optional)***.
- `--endpoint`: Selects an endpoint to fetch instead of fetching them all ***(optional)***.
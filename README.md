| :exclamation: Deprecation Notice |
|:-|
|We want to express our sincere gratitude for your support and contributions to the Lucid open source project. As we are no longer using this technology internally, we have come to the decision to archive the Lucid repository. While we won't be providing further updates or support, the existing code and resources will remain accessible for your reference. We encourage anyone interested to fork the repository and continue the project's legacy independently. Thank you for being a part of this journey and for your patience and understanding.|
---

# Lucid

Lucid is a Swift library for building robust data layers for applications.

- **Declarative**: Lucid makes it easy to declare complex data models and provides the tools to use it with plain Swift code.

- **Plug-and-play**: Use the stores which suit your data flow the best or write your own. Lucid gives you the infrastructure to seamlessly integrate the technologies you want to use.

- **Adaptability**: Built to fit most kinds of standard and non-standard server APIs, Lucid abstracts away server-side structural decisions by providing a universal client-side API.

## Quick Setup

To quickly bootstrap a project, try running the following:

```bash
$ mkdir MyProject && cd MyProject
$ lucid bootstrap
```

The bootstrap command creates a configuration file (`.lucid.yaml`) and an example of entity and endpoint description (under the directory `Descriptions`), which you can rename and edit at your convenience.

Then, to generate the code, run:

```bash
$ lucid swift
```

This command generates the code to insert in your project under the directory `Generated`.

## [Documentation](Documentation/Manual)

## Want to help?

You are more than welcome to contribute to Lucid. You can open a PR or file tickets here on Github. Please refer to our [contributions guidelines](CONTRIBUTING.md) before doing so.

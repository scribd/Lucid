![Tests](https://github.com/scribd/Lucid/workflows/Tests/badge.svg) ![Code Coverage](https://s3.amazonaws.com/mobile.scribd.com/badges/Lucid/CodeGen.svg)

# Lucid

Lucid is a Swift library for building robust data layers for applications.

- **Declarative**: Lucid makes it easy to declare complex data models and provides the tools to use it with plain Swift code.

- **Plug-and-play**: Use the stores which suit your data flow the best or write your own. Lucid gives you the infrastructure to seamlessly integrate the technologies you want to use.

- **Adaptability**: Built to fit most kinds of standard and non-standard server APIs, Lucid abstracts away server-side structural decisions by providing a universal client-side API.

## Quick Setup

To quickly boostrap a project, try running the following:

```bash
$ mkdir MyProject && cd MyProject
$ lucid bootstrap
```

The boostrap command creates a configuration file (`.lucid.yaml`) and an example of entity and endpoint description (under the directory `Descriptions`), which you can rename and edit at your convenience.

Then, to generate the code, run:

```bash
$ lucid swift
```

This command generates the code to insert in your project under the directory `Generated`.

## [Documentation](Documentation)

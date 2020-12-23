# Lucid - Extensions

For projects with very specific needs, Lucid supports extensions which have the ability to generate their own swift files, using the same environment and frameworks than the Lucid command line tool. 

## Setup Extensions

To setup one or more extensions, you'll need to add the field `extensions_path` to your [configuration file](ConfigurationAndDescriptionFiles.md#configuration-file). This path should point to where you want your extensions to be located.

Then, run the following at the root of your project:

```bash
$ lucid bootstrap
```

This command creates an example of extension (`MyExtension`) which you can use as a template to create your own.

Note that it also clones Lucid's repository at `$extensions_path/.lucid`. If you installed Lucid with a package manager, it is convenient to remove this clone and use the following instead:

- For Carthage:

	```bash
	$ ln -s Carthage/Checkout/Lucid $extensions_path/.lucid
	``` 

- For CocoaPods:

	```bash
	$ ln -s Pods/Lucid $extensions_path/.lucid
	```

- For Swift PM:

	```bash
	$ ln -s .build/checkouts/Lucid/CodeGen $extensions_path/.lucid
	```

This makes sure that your extensions use the same version of Lucid than the rest of your project.

## Files Structure

At your extensions location, the files structure should look like the following:

```bash
$ tree -a
.
├── .Package.swift
├── .gitignore
├── .lucid -> $path_to_lucid_clone
└── MyExtension
    ├── Package.resolved
    ├── Package.swift -> ../.Package.swift
    └── Sources
        └── Extension
            └── main.swift
```

As you can see, an extension is structured like a regular Swift PM project.

Note that you can place as many extension directories like `MyExtension` as you want, and Lucid will recognize them as such, as long as they are valid Swift PM projects.

## Write an Extension

To start writing an extension you'll need to generate an Xcode project using Swift PM:

```bash
$ swift package generate-xcodeproj
``` 

This will create for you the file `Extension.xcodeproj` which you can then open with Xcode.

You can then start writing the code of you extension which should contain a main file. 

For example:

```swift
// main.swift

import LucidCodeGenExtension
import LucidCodeGenCore
import PathKit

struct Generator: ExtensionGenerator {

  static let name = "MyExtensionGenerator" // Name of the extension.

  static let targetName: TargetName = .app // Target where the extension code is generated.

  private let parameters: GeneratorParameters

  init(_ parameters: GeneratorParameters) {
    self.parameters = parameters
  }

  func generate(for elements: [Description], in directory: Path, organizationName: String) throws -> [SwiftFile] {
    return elements.compactMap { element in
      switch element {
      case .all:
        return SwiftFile(
          content: "print("Hello World!")", // Generated code.
          path: directory + "MyExtension.swift" // Path where the file is generated.
        )
      default:
        return nil
      }
    }  
  }
}

// Runs the extension. Always make sure to have this code in the main file.
ExtensionCommands.generator(Generator.self).run()
```

## Run an Extension

Extensions are automatically built and run by the Lucid command line tool. Once your extension is ready, re-running `lucid swift` should execute it.

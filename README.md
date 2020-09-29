![Tests](https://github.com/scribd/Lucid/workflows/Tests/badge.svg) ![Code Coverage](https://s3.amazonaws.com/mobile.scribd.com/badges/Lucid/CodeGen.svg) 

# Lucid

Lucid is a Swift library for building robust data layers for applications.

- **Declarative**: Lucid makes it easy to declare complex data models and provides the tools to use it with plain Swift code.

- **Plug-and-play**: Use the stores which suit your data flow the best or write your own. Lucid gives you the infrastructure to seamlessly integrate the technologies you want to use.

- **Adaptability**: Built to fit most kinds of standard and non-standard server APIs, Lucid abstracts away server-side structural decisions by providing a resource oriented universal client-side API.

## Installation

### Lucid Run-time

#### [Carthage](https://github.com/Carthage/Carthage)

```
github "git@github.com:scribd/Lucid.git"
```

#### [CocoaPods](https://cocoapods.org) (coming soon)

```
pod 'Lucid'
```

#### [Swift Package Manager](https://swift.org/package-manager/) (coming soon)

```swift
// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "MyApp",
  dependencies: [
    .package(url: "https://github.com/scribd/Lucid.git", from: "1.0")
  ],
  targets: [
    .target(name: "MyApp", dependencies: ["Lucid"])
  ]
)
```

### Lucid Compile-time

#### Binary form

Download the latest release with the prebuilt binary from release tab. Unzip the archive into the desired destination and run `bin/lucid`

#### [Homebrew](https://brew.sh) (coming soon)

```bash
$ brew install lucid
```

#### Manually

```bash
$ git clone git@github.com:scribd/Lucid.git
$ cd Lucid/CodeGen
$ make install
```

When installing Lucid Run-time with:

- Carthage - use `$ cd Carthage/Checkout/Lucid/CodeGen`
- Cocoapods - use `$ cd Pods/Lucid/CodeGen`
- Swift Package Manager - use `$ cd .build/checkouts/Lucid/CodeGen`

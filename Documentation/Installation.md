# Lucid - Installation

## Run-time

### [Carthage](https://github.com/Carthage/Carthage)

```
github "git@github.com:scribd/Lucid.git"
```

### [CocoaPods](https://cocoapods.org) (coming soon)

```
pod 'Lucid'
```

### [Swift Package Manager](https://swift.org/package-manager/) (coming soon)

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

## Compile-time

### Binary form

Download the latest release with the prebuilt binary from release tab. Unzip the archive into the desired destination and run `bin/lucid`

### [Homebrew](https://brew.sh) (coming soon)

```bash
$ brew install lucid
```

### Manually

```bash
$ git clone git@github.com:scribd/Lucid.git
$ cd Lucid/CodeGen
$ make install
```

When installing Lucid Run-time with:

- Carthage - use `$ cd Carthage/Checkout/Lucid/CodeGen`
- Cocoapods - use `$ cd Pods/Lucid/CodeGen`
- Swift Package Manager - use `$ cd .build/checkouts/Lucid/CodeGen`
# Lucid - Installation

## Run-time

### [Carthage](https://github.com/Carthage/Carthage)

```
github "git@github.com:scribd/Lucid.git"
```

### [Swift Package Manager](https://swift.org/package-manager/)

In Xcode, `File -> Swift Packages -> Add Package Dependency -> Lucid`

If you are using `LucidTestKit`, you'll have to add `DISABLE_DIAMOND_PROBLEM_DIAGNOSTIC=YES` to your test target's build settings. You can learn more about this issue [here](https://forums.swift.org/t/swift-packages-in-multiple-targets-results-in-this-will-result-in-duplication-of-library-code-errors/34892/51). 

## Compile-time

### Binary form

Download the latest release with the prebuilt binary from [release tab](https://github.com/scribd/Lucid/releases). Unzip the archive into the desired destination and run `bin/lucid`

### [Homebrew](https://brew.sh)

```bash
$ brew install lucid
```

### Manually

```bash
$ git clone git@github.com:scribd/Lucid.git
$ cd Lucid/CodeGen
$ make install
```

When installing Lucid runtime with:

- Carthage - use `$ cd Carthage/Checkout/Lucid/CodeGen`
- Cocoapods - use `$ cd Pods/Lucid/CodeGen`
- Swift Package Manager - use `$ cd .build/checkouts/Lucid/CodeGen`
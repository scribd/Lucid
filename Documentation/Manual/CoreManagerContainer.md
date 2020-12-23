# Lucid - `CoreManagerContainer`

`CoreManagerContainer` is a convenience object generated by Lucid which contains one core manager per entity type.

Although it isn't required, we recommend using the `CoreManagerContainer`, as it facilitates the use of managers accross the project and avoids data synchronization issues.

## Data Synchronization

To understand why the container is useful, it's important to understand certain rules about core managers and data synchronization:

- `CoreManager` instances aren't synchronized with each other. This means that **writing data with one instance** of a core manager **won't** necessarily **update continuous publishers of other instances** of the same entity type.

- `CoreManagers` have an internal synchronization system in order to avoid overriding fresh data with outdated data. While this system doesn't share its state with other instances, it may share the same stores. Such a setup can lead to **data collisions** and **damage local stores' integrity**.

**Important:** Generally speaking, it is advised to only use one `CoreManager` instance per entity type in a project, which is where `CoreManagerContainer` comes in handy.

## Initialization

Buiding a `CoreManagerContainer` looks like the following:

```swift
let coreManagers = CoreManagerContainer(
  cacheLimit: 512,
  client: MyAPIClient(...),
  diskStoreConfig: .coreData  
)

coreManagers.myEntityManager.get(byID: ...)
```

The `CoreManagerContainer` depends on two objects:

1. [`APIClient`](./Client.md): An interface to your network APIs
2. `DiskStoreConfig`: A struct containing any needed data to build your disk stores.

By default, `CoreManagers` use an `InMemoryStore` as a caching system in front of a `CoreDataStore`. That's why it is required to set the `cacheLimit` to a reasonable value as it is the maximum amount of entities the `InMemoryStore` can contain per entity type.

## Default Store Configuration

`CoreManagerContainer` automatically creates the stores which are being injected into the core managers. 

By default, it uses the following:

- `LocalEntity` => `InMemoryStore`
- `CoreDataEntity`=> `InMemoryStore` + `CoreDataStore`
- `RemoteEntity` => `RemoteStore`
- `CoreDataEntity` + `RemoteEntity` => `InMemoryStore` + `CoreDataStore` + `RemoteStore`

## Custom Store Configuration

The `CoreManagerContainer` file contains all of the default stores that will be used for all entities. This demonstrates the same way you can configure your own stores for any given entity type. In a separate file, simply add:

```swift
extension MyEntityType {
  
  static func stores(with client: APIClient,
                     clientQueue: inout APIClientQueue,
                     cacheLimit: Int,
                     diskStoreConfig: CoreManagerContainer.DiskStoreConfig) -> [Storing<MyEntityType>] { 
    return [...]
  }
}
```

Note that `DiskStoreConfig` has a custom property which can be any type of data you want to inject in order to build your own local stores.
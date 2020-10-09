# Lucid - [CoreManager](../Lucid/Core/CoreManager.swift)

`CoreManager`s are the only interface Lucid provides to read and write entities to the stores.  

Every method of `CoreManager` takes a `ReadContext<E>`/`WriteContext<E>`, and returns an object of type `AnyPublisher<QueryResult<E>, ManagerError>`.

- `ReadContext<E>`/`WriteContext<E>`: Context objects contain contextual information about where entities should come from (data source), when they should be stored (target), and sometimes which endpoint should be reached and how the served data should be parsed.

- `AnyPublisher` comes from the library `Combine` and allows you to subscribe to asynchronous events. For some operations, only one event is sent with a result, for some other operations, multiple events can be sent, so in a way, a publisher can be seen as a stream of results.

- `QueryResult<E>` is an object containing the requested entities. Depending on the operation, results can be grouped, or forming a simple list or even a single entity. `QueryResult` allows to retrieve the data in whichever format is expected.

- `ManagerError` is an enum for which every case represents an error that can happen when requesting entities. The errors are classified per domain to make it easier to understand the cause.

## Get Entity By Id

Looking for entity using its identifier is the prefered way to fetch a unique entity. It is usually faster than using a search query.

```swift
manager
  .get(byID: myEntityIdentifier, in: ReadContext<MyEntity>(dataSource: .local))
  .sink(receiveCompletion: { ... }, receiveValue: { ... })
  .store(in: cancellables)
```

## Search Entities With Query

Looking for entities is done through the `search` operation. 

It requires to pass a query as parameter. A `Query<E>` is an object holding the information necessary to filter, group, sort entities.

```swift
let publishers = manager.search(
  withQuery: .filter(.identifier << [myEntityIdentifierOne, myEntityIdentifierTwo]),
  in: ReadContext<MyEntity>(dataSource: .local)
)

publishers
   .once
   .sink(receiveCompletion: { ... }, receiveValue: { ... }) // Receiving once.
   .store(in: cancellables)
   
publishers
	.continuous
   .sink(receiveCompletion: { ... }, receiveValue: { ... }) // Receiving for every data change.
   .store(in: cancellables)
```

The `search` operation returns two publishers:

- `once` receives one unique result. It is usually used for operations which don't require to be reactive to changes.
- `continuous` receives one result per data change. It is usually used for refreshing views in a reactive manner.

## Set Entity

A mutable entity can be set using the `set` operation.

```swift
let myEntity = MyEntity(...)

manager
  .set(myEntity, in: WriteContext(dataTarget: .local))
  .sink(receiveCompletion: { ... }, receiveValue: { ... })
  .store(in: cancellables)
```

## Set Entities

The same way one mutable entity can be set, a list of entities can be set using the same operation.

```swift
let myEntities = [
  MyEntity(...),
  MyEntity(...)  
]

manager
  .set(myEntities, in: WriteContext(dataTarget: .local))
  .sink(receiveCompletion: { ... }, receiveValue: { ... })
  .store(in: cancellables)
```

## Remove Entity At Identifier

The most performant way to remove one single entity is to use the `remove` operation with its identifier.

```swift
manager
  .remove(at: myEntityIdentifier, in: WriteContext(dataTarget: .local))
  .sink(receiveCompletion: { ... }, receiveValue: { ... })
  .store(in: cancellables)
```

## Remove Entities With Idenfiers

The same way one entity can be removed, a multiple entities can be removed using the same operation and a list of identifiers.

```swift
manager
  .remove([myEntityIdentifierOne, myEntityIdentifierTwo], in: WriteContext(dataTarget: .local))
  .sink(receiveCompletion: { ... }, receiveValue: { ... })
  .store(in: cancellables)
```

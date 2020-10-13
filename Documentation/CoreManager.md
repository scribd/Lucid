# Lucid - [CoreManager](../Lucid/Core/CoreManager.swift)

`CoreManager`s are the only interface Lucid provides to read and write entities to the stores.  

Every method of `CoreManager` takes a `ReadContext<E>`/`WriteContext<E>`, and returns an object of type `AnyPublisher<QueryResult<E>, ManagerError>`.

- `AnyPublisher` comes from the library `Combine` and allows you to subscribe to asynchronous events. For some operations, only one event is sent with a result, for some other operations, multiple events can be sent, so in a way, a publisher can be seen as a stream of results.

- `QueryResult<E>` is an object containing the requested entities. Depending on the operation, results can be grouped, or forming a simple list or even a single entity. `QueryResult` allows to retrieve the data in whichever format is expected.

- `ManagerError` is an enum for which every case represents an error that can happen when requesting entities. The errors are classified per domain to make it easier to understand the cause.

## Contexts

Context objects contain contextual information about where entities should come from (data source), when they should be stored (target), and sometimes which endpoint should be reached and how the served data should be parsed

### ReadContext

`ReadContext` is a context used with read operations.

To build it, the following parameters are to be passed:

- **Data Source**: Describes where the data comes from (defaults to `.local`).

	There are few useful combinations of data source:
	- `.local`: The data can only come from local stores.
	- `.remote`: The data can only come from remote stores. By default, the endpoint to reach is derived from the entity type (`endpoint: .derivedFromEntityType`), the served entities will automatically be saved to the local stores (`persistenceStrategy: .persist(.retainExtraLocalData)`) without considering them as a complete set (`trustRemoteFiltering: false`).
	- `.remote(endpoint: .request(APIRequestConfig(...), resultPayload: .myPayload))`: The data comes from the server's response to the specified request, using `myPayload` for parsing.
	- `.remoteOrLocal(...)`: The data come from the remote stores. If for any reason they aren't remotely accessible, Lucid fallsback to using the local stores.
	- `.localThenRemote(...)`: The data come from the local stores, then from the remote stores. The second event can be observed using a continuous publisher.

- **Contract**: Object in charge of validating the data coming through (defaults: `AlwaysValidContract()`).

- **Access Validator**: Object in charge of validating that the data coming through is accessible to the current user (optional).

### WriteContext

`WriteContext` is a context used with write operations.

To build it, the following parameters are to be passed:

- **Data Target**: Describes where the data goes (required).

	A target can be one of the following:
	- `.local`: Saves to the local stores only.
	- `.remote(endpoint: .request(APIRequestConfig(...)))`: Saves to the remote stores using the specified API request.
	- `.remote(endpoint: .derivedFromPath({ ... }))`: Saves to the remote stores using the specified builder.
	- `.remote(endpoint: .derivedFromEntityType)`: Saves to the remote stores by derivating the API request from the entity type.
	- `.localAndRemote(endpoint: ...)`: Saves to both local and remote stores.

- **Access Validator**: Object in charge of validating that the data target is accessible to the current user (optional).

## Query

Queries are objects used to filter, group, order or paginate entities.

### Comparison Operators

- Equality:

	```swift
	Query<MyEntity>.filter(.myProperty == .string("my_property_value"))
	Query<MyEntity>.filter(.myProperty != .string("my_property_value"))
	
	Query<MyEntity>.filter(.identifier == .identifier(myEntityIdentifier))
	Query<MyEntity>.filter(.identifier != .identifier(myEntityIdentifier))
	```
	
- Regex:

	```swift
	Query<MyEntity>.filter(.myProperty ~= .string("my_property_.*"))
	```

- Comparison:

	```swift
	Query<MyEntity>.filter(.myProperty > .string("my_property_value"))
	Query<MyEntity>.filter(.myProperty >= .string("my_property_value"))
	Query<MyEntity>.filter(.myProperty < .string("my_property_value"))
	Query<MyEntity>.filter(.myProperty <= .string("my_property_value"))
	```
	
### Logical Operators

- Or:

	```swift
	Query<MyEntity>.filter(.myProperty == .string("value_one") || .myProperty == .string("value_two"))
	```

- And:

	```swift
	Query<MyEntity>.filter(.myProperty > .int(0) && .myProperty < .int(10))
	```

- Not:

	```swift
	Query<MyEntity>.filter(!(.myProperty == .string("my_property_value")))
	```

### Contained In 

- With a property:

	```swift
	Query<MyEntity>.filter(.myProperty >> ["my_property_value_one", "my_property_value_two"])
	```

- With an identifier:

	```swift
	Query<MyEntity>.filter(.identifier >> myEntityIdentifiers)
	```

### Order By

- `.asc`/`.desc`:

	```swift
	Query<MyEntity>.all.order([.asc(by: .myProperty)])
	
	Query<MyEntity>.all.order([.desc(by: .myProperty)])
	```

- `.natural`: Keeps the natural order served by the remote stores. Only makes sense for remote stores.

	```swift 
	Query<MyEntity>.all.order([.natural])
	```

- `.identifiers`: Restitutes the passed identifiers' order

	```swift
	Query<MyEntity>.all.order([.identifiers(myEntityIdentfiers)])
	```

### Group By

```swift
Query<MyEntity>.all.grouped(by: .myProperty)
```

### Pagination

```swift
Query<MyEntity>.all.with(offset: 42).with(limit: 10)
```

### Complex Query

```swift
Query<MyEntity>
  .filter(.myProperty ~= .string("my_property_.*") && .myProperty != .string("excluded_value"))
  .order([.desc(.myProperty)])
  .with(limit: 10)
```

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
  .sink(receiveCompletion: { [weak self] ... }, receiveValue: { [weak self] ... }) // Receiving for every data change.
  .store(in: cancellables)
```

The `search` operation returns two publishers:

- `once` receives one unique result. It is usually used for operations which don't require to be reactive to changes.
- `continuous` receives one result per data change. It is usually used for refreshing views in a reactive manner.

When using a continuous publisher, it is important to make sure there isn't a possibility of retain cycle between the receive blocks and the cancellables store. Unlike for a once publisher, `CoreManager` retains continuous publishers until they aren't in used anymore. If a retain cycle keeps the publisher alive, `CoreManager` will keep track of it forever, which might become expensive over time.

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

## Remove Entities With Identifiers

The same way one entity can be removed, a multiple entities can be removed using the same operation and a list of identifiers.

```swift
manager
  .remove([myEntityIdentifierOne, myEntityIdentifierTwo], in: WriteContext(dataTarget: .local))
  .sink(receiveCompletion: { ... }, receiveValue: { ... })
  .store(in: cancellables)
```

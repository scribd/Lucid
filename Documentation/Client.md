# Lucid - `Client`

Lucid uses two important objects in order to send and receive information from the network.

- `APIClient` which is the lowest interface level between the `RemoteStore`s and your servers.
- `APIClientQueue` which is in charge of picking the most appropriate time to send and/or, when they fail, retry sending requests.

While `APIClientQueue` has a full implementation provided by Lucid, `APIClient` is only a partially implemented protocol which requires more attention.

## Client Configuration

To configure your own client, you'll have to create an object implementing the `APIClient` protocol.

It requires the following properties:

- `networkClient`: An interface to the network layer of iOS. You can create an object implementing the protocol `NetworkClient` or simply use `URLSession`.
- `identifier`: Which is a string used for logging only.
- `host`: The base URL of you server's endpoints (e.g. `https://my_server.com/api/v1`).
- `deduplicator`: Object in charge of deduplicating similar requests sent at the same time. You can choose to use `APIRequestDeduplicator` provided by Lucid or implement your own.

It also requires the following methods:

- `func prepareRequest(_ requestConfig: APIRequestConfig, completion: @escaping (APIRequestConfig) -> Void)`: This method is called before sending a request. It's well suited for any shared configuration between requests (e.g. setting an API key or an authentication token in the request's headers).

- `func errorPayload(from body: Data) -> APIErrorPayload?`: This method is called when receiving an error status. It is an opportunity to convert an error payload into an `APIErrorPayload` object which Lucid can understand.

## Request Configuration

`APIClient` is sending requests which are represented by a struct named `APIRequestConfig`. 

A request can be configured using the following attributes:

- `method`: Method to be used for sending the request (defaults to `.get`).
- `path`: Path to an endpoint (required). Being appended to the `host`. 
- `host`:  Overrides the `host` property implemented in `APIClient` (optional).
- `query`: A list of key/values being appended to the request's URL (optional).
- `headers`: A list of key/values being added to the request's headers (optional).
- `body`: Data added used as the request's body (optional). Can be either `.rawData` or `.formURLEncoded`. 
- `includeSessionKey`: Whether or not the request should be authenticated (defaults to `true`).
- `timeoutInterval`: Interval of time after which the request is expected to be cancelled (optional).
- `deduplicate`: Whether or not the request should be deduplicated in the event several of them are similar and sent at the same time (defaults to `true`).
- `tag`: A tag used for logging.
- `queueingStrategy`: Describes how the request should be queued if it needs to (optional).
- `background`: Whether or not the request should start a [background task](https://developer.apple.com/documentation/backgroundtasks) (defaults to `true`).

## Request Queueing

When Lucid gets a request to send from a `RemoteStore`, it doesn't always directly sends it, and that for two reasons:

- Some requests need more attention because they carry important information which can't be lost in case of failure or if the app gets terminated. For instance, requests using the method `POST` or `PUT` almost always carry a body, which needs to be safely brought to the server's attention.

- Some requests depend on one another and need to be sent sequentially so that the server can make sense out of them. For example, if request A creates an entity on the backend and request B updates that same entity, it only make sense to send those requests in the order A => B.

For these reasons, Lucid first appends the requests to an `APIClientQueue` before sending them. The queue then decides if yes or not they should be sent in parrallele or sequentially, but also makes sure that requests carrying important data have the opportunity to re-enter in the queue after a network failure.

## Response Handler

Lucid has two ways to propagate server response into its system:

1. Through a `CoreManager`s publisher.
2. Through a *static* response handler.

The first option is commonly used for read-only requests. When the app needs information to show to the screen, it fetches those data from the server and immediately apply them.

The second option is used for requests which aren't always sent immediately, potentially after the app was restarted.

### Registering a Response Handler

To register a response handler you'll have to implement the `CoreManagerContainerClientQueueResponseHandler` protocol and make sure `CoreManagerContainer` is aware of it.

```swift
final class MyResponseClientQueueHandler: CoreManagerContainerClientQueueResponseHandler {
  
  func clientQueue(_ clientQueue: APIClientQueuing,
                   didReceiveResponse result: APIClientQueueResult<Data, APIError>,
                   for request: APIClientQueueRequest) {
    ...
  }
}

extension CoreManagerContainer {
    static func makeResponseHandler() -> CoreManagerContainerClientQueueResponseHandler? {
        return MyResponseClientQueueHandler()
    }
}
``` 

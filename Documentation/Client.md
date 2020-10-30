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

- ```swift
func prepareRequest(_ requestConfig: APIRequestConfig, completion: @escaping (APIRequestConfig) -> Void)
```
This method is called before sending a request. It's well suited for any shared configuration between requests (e.g. setting an API key or an authentication token in the request's headers).

- ```swift
func errorPayload(from body: Data) -> APIErrorPayload?
```
This method is called when receiving an error status. It is an opportunity to convert an error payload into an `APIErrorPayload` object which Lucid can understand.

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


 
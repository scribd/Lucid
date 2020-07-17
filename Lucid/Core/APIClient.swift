//
//  APIClient.swift
//  Lucid
//
//  Created by Théophane Rupin on 10/8/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import ReactiveKit

#if !LUCID_REACTIVE_KIT
import Combine
#endif

// MARK: - Error

public enum APIError: Error, Equatable {
    case networkingProtocolIsNotHTTP
    case network(Error)
    case internetConnectionFailure(Error)
    case url
    case deserialization(Error)
    case emptyBodyResponse
    case api(httpStatusCode: Int, errorPayload: APIErrorPayload?)
    case sessionKeyMismatch
}

// MARK: - Request Config

public struct APIRequestConfig: Codable, Hashable {

    fileprivate enum Constants {
        static let identifierPlaceholderPrefix = ":identifier_"
    }

    public enum QueryValue: Codable, Hashable {
        case _value(String)
        case identifier(key: String, localValue: String)
        indirect case _array([QueryValue])

        public static func value(_ value: String?) -> QueryValue? {
            return value.flatMap { ._value($0) }
        }

        public static func value(_ value: QueryResultConvertible?) -> QueryValue? {
            return .value(value?.requestValue)
        }

        public static func value(_ array: [QueryValue]?) -> QueryValue? {
            return array.flatMap { ._array($0) }
        }

        public static func value(_ strings: [String]?) -> QueryValue? {
            return .value(strings?.map { ._value($0) })
        }

        public static func value(_ strings: [QueryResultConvertible]?) -> QueryValue? {
            return .value(strings?.map { ._value($0.requestValue) })
        }

        public static func + (lhs: QueryValue, rhs: QueryValue) -> QueryValue {
            switch (lhs, rhs) {
            case (._value(let lhsString), ._value(let rhsString)):
                return ._value(lhsString + rhsString)
            case (._array(let lhsValues), ._array(let rhsValues)):
                return ._array(lhsValues + rhsValues)
            case (._value, _),
                 (.identifier, _),
                 (._array, _):
                Logger.log(.verbose, "\(APIRequestConfig.QueryValue.self) attempting to add two incompatible types. Ignoring RHS argument.", assert: true)
                return lhs
            }
        }

        public var hashStringValue: String {
            switch self {
            case .identifier(let key, let localValue):
                return "(\(key),\(localValue))"
            case ._array(let values):
                return "[\(values.map { $0.hashStringValue }.joined(separator: ","))]"
            case ._value(let value):
                return value
            }
        }
    }

    public enum Body: Codable, Hashable {
        case raw(Data)
        case _formURLEncoded(OrderedDictionary<String, QueryValue>)

        public static func formURLEncoded(_ values: OrderedDictionary<String, QueryValue>) -> Body {
            return ._formURLEncoded(values)
        }

        public static func formURLEncoded(_ values: [(key: String, value: QueryValue?)]) -> Body {
            return ._formURLEncoded(OrderedDictionary(values.lazy.compactMap { key, value in
                value.flatMap { (key, $0) }
            }))
        }
    }

    public enum Path: Codable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
        case component(String)
        case identifier(key: String, localValue: String)
        indirect case path(parent: Path, child: Path)
    }

    public struct QueueingStrategy: Codable, Hashable {
        public enum Synchronization: Int, Codable, Hashable {
            case concurrent
            case barrier
        }

        public let synchronization: Synchronization
        public let retryOnInternetConnectionFailure: Bool

        public init(synchronization: Synchronization,
                    retryOnInternetConnectionFailure: Bool) {
            self.synchronization = synchronization
            self.retryOnInternetConnectionFailure = retryOnInternetConnectionFailure
        }
    }

    private struct Core: Codable, Hashable {
        let method: HTTPMethod
        let host: String?
        var path: Path
        var query: OrderedDictionary<String, QueryValue>
        var headers: OrderedDictionary<String, String>
        var body: Body?
        var includeSessionKey: Bool
        var timeoutInterval: TimeInterval?
        var queueingStrategy: QueueingStrategy?
        var background: Bool?
    }

    private var core: Core

    public var method: HTTPMethod {
        return core.method
    }
    public var host: String? {
        return core.host
    }
    public var path: Path {
        get { return core.path }
        set { core.path = newValue }
    }
    public var query: OrderedDictionary<String, QueryValue> {
        get { return core.query }
        set { core.query = newValue }
    }
    public var headers: OrderedDictionary<String, String> {
        get { return core.headers }
        set { core.headers = newValue }
    }
    public var body: Body? {
        get { return core.body }
        set { core.body = newValue }
    }
    public var includeSessionKey: Bool {
        get { return core.includeSessionKey }
        set { core.includeSessionKey = newValue }
    }
    public var timeoutInterval: TimeInterval? {
        get { return core.timeoutInterval }
        set { core.timeoutInterval = newValue }
    }
    public var queueingStrategy: QueueingStrategy {
        get { return core.queueingStrategy ?? core.method.defaultQueueingStrategy }
        set { core.queueingStrategy = newValue }
    }
    public var background: Bool {
        get { return core.background ?? core.method.defaultBackground }
        set { core.background = newValue }
    }

    public let deduplicate: Bool
    public let tag: String?

    public init(method: HTTPMethod,
                path: Path,
                host: String? = nil,
                query: [(String, QueryValue?)] = [],
                headers: [(String, String?)] = [],
                body: Body? = nil,
                includeSessionKey: Bool = true,
                timeoutInterval: TimeInterval? = nil,
                deduplicate: Bool? = nil,
                tag: String? = nil,
                queueingStrategy: QueueingStrategy? = nil,
                background: Bool? = nil) {

        self.core = Core(method: method,
                         host: host,
                         path: path,
                         query: OrderedDictionary(query.compactMap { key, value in value.flatMap { (key, $0) } }),
                         headers: OrderedDictionary(headers.compactMap { key, value in value.flatMap { (key, $0) } }),
                         body: body,
                         includeSessionKey: includeSessionKey,
                         timeoutInterval: timeoutInterval,
                         queueingStrategy: queueingStrategy,
                         background: background)
        self.deduplicate = {
            if let deduplicate = deduplicate { return deduplicate }
            switch method {
            case .get,
                 .head:
                return true
            case .delete,
                 .post,
                 .put:
                return false
            }
        }()
        self.tag = tag
    }

    public static func == (lhs: APIRequestConfig, rhs: APIRequestConfig) -> Bool {
        return lhs.core == rhs.core
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(core)
    }
}

public struct APIJSONCoderConfig {
    public var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase
    public var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToSnakeCase
    public var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy?
    public var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy?

    public init() {
        // no-op
    }
}

// MARK: - Request

/// Representation of a request to send to a server where `Model` is the
/// expected type built from the response.
public struct APIRequest<Model>: Equatable {

    /// Request configurations.
    public var config: APIRequestConfig

    public init(_ config: APIRequestConfig) {
        self.config = config
    }

    public init(method: HTTPMethod = .get,
                host: String? = nil,
                path: APIRequestConfig.Path,
                query: [(String, APIRequestConfig.QueryValue?)] = [],
                headers: [(String, String?)] = [],
                body: APIRequestConfig.Body? = nil,
                tag: String? = nil,
                queueingStrategy: APIRequestConfig.QueueingStrategy? = nil) {

        let config = APIRequestConfig(method: method,
                                      path: path,
                                      host: host,
                                      query: query,
                                      headers: headers,
                                      body: body,
                                      tag: tag,
                                      queueingStrategy: queueingStrategy)
        self.init(config)
    }
}

// MARK: - Response

public struct APIResponseHeader {

    public let cachedResponse: Bool

    public let etag: String?

    public init(with headerFields: [AnyHashable: Any]) {
        self.cachedResponse = (headerFields["Status"] as? String)?.contains("304 Not Modified") ?? false
        self.etag = headerFields["Etag"] as? String
    }

    static var empty: APIResponseHeader { return APIResponseHeader(with: [:]) }
}

public struct APIClientResponse<T> {

    public let data: T

    public let header: APIResponseHeader

    public let cachedResponse: Bool

    public let jsonCoderConfig: APIJSONCoderConfig

    public init(data: T, urlResponse: HTTPURLResponse, jsonCoderConfig: APIJSONCoderConfig = APIJSONCoderConfig()) {
        self.data = data
        self.header = APIResponseHeader(with: urlResponse.allHeaderFields)
        self.cachedResponse = header.cachedResponse
        self.jsonCoderConfig = jsonCoderConfig
    }

    public init(data: T, cachedResponse: Bool, jsonCoderConfig: APIJSONCoderConfig = APIJSONCoderConfig()) {
        self.data = data
        self.header = .empty
        self.cachedResponse = cachedResponse
        self.jsonCoderConfig = jsonCoderConfig
    }

    public func with<O>(data: O) -> APIClientResponse<O> {
        return APIClientResponse<O>(
            data: data,
            cachedResponse: cachedResponse,
            jsonCoderConfig: jsonCoderConfig
        )
    }
}

// MARK: - Error payload

public struct APIErrorPayload: Equatable {
    public let apiStatusCode: Int?
    public let message: String?

    public init(apiStatusCode: Int?,
                message: String?) {
        self.apiStatusCode = apiStatusCode
        self.message = message
    }
}

// MARK: - API

/// Client able to send HTTP requests to a host.
public protocol APIClient: AnyObject {

    /// Identifier used for logging.
    var identifier: String { get }

    /// Host to reach. Eg. `"https://api.scribd.com"`
    var host: String { get }

    var networkClient: NetworkClient { get }

    var deduplicator: APIRequestDeduplicating { get }

    /// Send a request to the server.
    ///
    /// - Parameters:
    ///     - request: Data request to send.
    ///     - completion: Block to be called with either the retrieved `Data` or an `APIError`.
    func send(request: APIRequest<Data>, completion: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void)

    /// Send a request to the server.
    ///
    /// - Parameters:
    ///     - request: `Model` request to send.
    ///     - completion: Block to be called with either the retrieved `Model` or an `APIError`.
    /// - Note: Automatically decode the retrived `Data` to a given `Model` type.
    func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<APIClientResponse<Model>, APIError>) -> Void) where Model: Decodable

    /// Determine if the current state is consistent from when the request was sent, and the response should be handled.
    ///
    /// - Parameters:
    ///     - requestConfig: The configuration of the request being sent.
    /// - Returns: A bool determining if the response is handled or ignored.
    func shouldHandleResponse(for requestConfig: APIRequestConfig, completion: @escaping (Bool) -> Void)

    /// Allows the client to track events that were sent. This will not be called for deduplicated requests.
    ///
    /// - Parameters:
    ///     - request: Data that was sent.
    func didSend(request: APIRequest<Data>)

    /// Provide an error payload from a response's body if this one contains an error's info.
    func errorPayload(from body: Data) -> APIErrorPayload?

    /// Provide a `Model` from a response's body.
    ///
    /// - Parameters:
    ///     - body: Response's body `Data`.
    ///     - coderConfig: Contains the `Decoder` to use for `JSON` deserialization.
    /// - Returns: The deserialized `Model`.
    /// - Throws: A `DecodingError` when the `Data` aren't valid.
    func response<Model>(from body: Data, with coderConfig: APIJSONCoderConfig) throws -> Model where Model: Decodable

    /// Prepare a request to be sent to the server.
    ///
    /// - Parameters:
    ///     - requestConfig: Request configuration to prepare.
    /// - Returns: Prepared copy of a given request configuration.
    /// - Note: A good place to add default headers/query strings.
    func prepareRequest(_ requestConfig: APIRequestConfig, completion: @escaping (APIRequestConfig) -> Void)

    /// Build a JSONCoder configuration to encode/decode client data.
    ///
    /// - Returns: Prepared copy of a given coder configuration.
    func jsonCoderConfig() -> APIJSONCoderConfig

    /// Encode a query string.
    ///
    /// - Parameters:
    ///     - query: The query strings' key/values.
    /// - Returns: Encoded query string.
    /// - Throws: An `APIRequestConfig.QueryValue.URLEncodingError` when the `query` cannot be URL-encoded
    /// - Note: A good place to implement a custom query string encoding.
    static func encodeQuery(_ query: OrderedDictionary<String, APIRequestConfig.QueryValue>) throws -> String

    /// Encode a body.
    ///
    /// - Parameters:
    ///     - body: The body to be encoded.
    /// - Returns: Encoded body data.
    /// - Throws: An `APIRequestConfig.Body.EncodingError`
    static func encodeBody(_ body: APIRequestConfig.Body) throws -> Data
}

// MARK: - Default Implementation

extension APIClient {

    public func send(request: APIRequest<Data>, completion: @escaping (Result<APIClientResponse<Data>, APIError>) -> Void) {

        prepareRequest(request.config) { requestConfig in

            let requestDescription = self.description(for: requestConfig)

            self.deduplicator.testForDuplication(request: requestConfig, handler: completion) { isDuplicate in

                guard isDuplicate == false else {
                    Logger.log(.info, "\(APIClient.self): \(self.identifier): Found request in progress that is identical to \(requestDescription). Deduplicating.")
                    return
                }

                let wrappedCompletion: (Result<APIClientResponse<Data>, APIError>) -> Void = { result in
                    completion(result)
                    self.deduplicator.applyResultToDuplicates(request: requestConfig, result: result)
                }

                let host = requestConfig.host ?? self.host
                guard let urlRequest = requestConfig.urlRequest(host: host, queryEncoder: Self.encodeQuery, bodyEncoder: Self.encodeBody) else {
                    wrappedCompletion(.failure(.url))
                    return
                }

                var request = request
                request.config = requestConfig

                Logger.log(.info, "\(APIClient.self): \(self.identifier): Requesting \(requestDescription).")

                let task = self.networkClient.dataTask(with: urlRequest) { (data, response, error) in

                    self.shouldHandleResponse(for: requestConfig) { shouldHandle in

                        guard shouldHandle else {
                            Logger.log(.debug, "\(Self.self): \(self.identifier): Session has changed since request \(urlRequest) was sent. Ignoring response.")
                            wrappedCompletion(.failure(.sessionKeyMismatch))
                            return
                        }

                        if let error = error as NSError? {
                            let apiError = APIError(network: error)
                            if case .internetConnectionFailure = apiError {
                                Logger.log(.debug, "\(Self.self): \(self.identifier): Internet connection failure occurred for request: \(urlRequest): \(error)")
                            } else {
                                Logger.log(.error, "\(Self.self): \(self.identifier): Error occurred for request: \(urlRequest): \(error)")
                            }
                            wrappedCompletion(.failure(apiError))
                            return
                        }

                        guard let response = response as? HTTPURLResponse else {
                            let error = APIError.networkingProtocolIsNotHTTP
                            Logger.log(.error, "\(Self.self): \(self.identifier): Error occurred for request: \(urlRequest): \(error)")
                            wrappedCompletion(.failure(error))
                            return
                        }

                        guard response.isSuccess else {
                            let errorPayload = data.flatMap { self.errorPayload(from: $0) }
                            let error = APIError.api(httpStatusCode: response.statusCode, errorPayload: errorPayload)
                            Logger.log(.error, "\(Self.self): \(self.identifier): Error occurred for request: \(urlRequest): \(error)")
                            wrappedCompletion(.failure(error))
                            return
                        }

                        guard let data = data else {
                            let error = APIError.emptyBodyResponse
                            Logger.log(.error, "\(Self.self): \(self.identifier): Error occurred for request: \(urlRequest): \(error)")
                            wrappedCompletion(.failure(error))
                            return
                        }

                        Logger.log(.info, "\(Self.self): \(self.identifier): Request succeeded: \(requestDescription).")
                        wrappedCompletion(.success(APIClientResponse(data: data, urlResponse: response, jsonCoderConfig: self.jsonCoderConfig())))
                    }
                }

                task.resume()
            }

            self.didSend(request: request)
        }
    }

    public func send<Model>(request: APIRequest<Model>, completion: @escaping (Result<APIClientResponse<Model>, APIError>) -> Void) where Model: Decodable {

        let dataRequest = APIRequest<Data>(request.config)

        send(request: dataRequest) { result in

            switch result {
            case .success(let response):
                do {
                    let model: Model = try self.response(from: response.data, with: response.jsonCoderConfig)
                    completion(.success(response.with(data: model)))
                } catch {
                    completion(.failure(.deserialization(error)))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func shouldHandleResponse(for requestConfig: APIRequestConfig, completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    public func didSend(request: APIRequest<Data>) {}

    public func response<Model>(from body: Data, with coderConfig: APIJSONCoderConfig) throws -> Model where Model: Decodable {
        return try coderConfig.decoder.decode(Model.self, from: body)
    }

    public func prepareRequest(_ requestConfig: APIRequestConfig, completion: @escaping (APIRequestConfig) -> Void) {
        completion(requestConfig)
    }

    public func jsonCoderConfig() -> APIJSONCoderConfig {
        return APIJSONCoderConfig()
    }

    public static func encodeQuery(_ query: OrderedDictionary<String, APIRequestConfig.QueryValue>) throws -> String {
        guard query.isEmpty == false else {
            return String()
        }
        return try query.orderedKeyValues.lazy.map { (key, value) in
            try value.encodedValue(for: key)
        }.joined(separator: "&")
    }

    public static func encodeBody(_ body: APIRequestConfig.Body) throws -> Data {
        switch body {
        case .raw(let data):
            return data

        case ._formURLEncoded(let data):
            do {
                let data = try data.orderedKeyValues
                    .map { (key, value) in try value.encodedValue(for: key) }
                    .joined(separator: "&")
                    .data(using: .utf8)

                guard let _data = data else {
                    throw APIRequestConfig.Body.EncodingError.utf8Encoding
                }
                return _data
            } catch {
                throw APIRequestConfig.Body.EncodingError.formURLEncoding(error)
            }
        }
    }

    public func description(for request: APIRequestConfig) -> String {
        guard let url = request.urlRequest(host: host, queryEncoder: Self.encodeQuery, bodyEncoder: Self.encodeBody)?.url else {
            return "Invalid request."
        }

        let base = "\(request.method.rawValue.uppercased()) - \(url.absoluteString)"
        if let tag = request.tag {
            return "\(base) (\(tag))"
        } else {
            return base
        }
    }
}

// MARK: - Payload Conversion Utils

public extension ResultPayloadConvertible {

    static func make(from response: APIClientResponse<Data>, endpoint: Endpoint) -> Result<Self, APIError> {
        do {
            return .success(try Self(from: response.data, endpoint: endpoint, decoder: response.jsonCoderConfig.decoder))
        } catch {
            return .failure(.deserialization(error))
        }
    }
}

// MARK: - Reactive API

public extension APIClient {

    private func _send(request: APIRequest<Data>) -> Signal<APIClientResponse<Data>, APIError> {
        return FutureSubject { fulfill in
            self.send(request: request) { result in
                switch result {
                case .success(let response):
                    fulfill(.success(response))
                case .failure(let error):
                    fulfill(.failure(error))
                }
            }
        }.toSignal()
    }

    #if LUCID_REACTIVE_KIT
    func send(request: APIRequest<Data>) -> Signal<APIClientResponse<Data>, APIError> {
        return _send(request: request)
    }
    #else
    func send(request: APIRequest<Data>) -> AnyPublisher<APIClientResponse<Data>, APIError> {
        return _send(request: request).toPublisher().eraseToAnyPublisher()
    }
    #endif

    private func _send<Model>(request: APIRequest<Model>) -> Signal<APIClientResponse<Model>, APIError> where Model: Decodable {
        return FutureSubject { fulfill in
            self.send(request: request) { result in
                switch result {
                case .success(let response):
                    fulfill(.success(response))
                case .failure(let error):
                    fulfill(.failure(error))
                }
            }
        }.toSignal()
    }

    #if LUCID_REACTIVE_KIT
    func send<Model>(request: APIRequest<Model>) -> Signal<APIClientResponse<Model>, APIError> where Model: Decodable {
        return _send(request: request)
    }
    #else
    func send<Model>(request: APIRequest<Model>) -> AnyPublisher<APIClientResponse<Model>, APIError> where Model: Decodable {
        return _send(request: request).toPublisher().eraseToAnyPublisher()
    }
    #endif

}

// MARK: - Identifier Placeholder

private extension String {

    var toIdentifierPlaceholder: (key: String, localValue: String)? {
        guard starts(with: APIRequestConfig.Constants.identifierPlaceholderPrefix) else { return nil }

        let keyAndLocalValue = self
            .replacingOccurrences(of: APIRequestConfig.Constants.identifierPlaceholderPrefix, with: String())
            .split(separator: ":")

        if keyAndLocalValue.count == 2 {
            return (key: String(keyAndLocalValue[0]), localValue: String(keyAndLocalValue[1]))
        } else {
            return nil
        }
    }

    static func identifierPlaceholderString(key: String, localValue: String) -> String {
        return "\(APIRequestConfig.Constants.identifierPlaceholderPrefix)\(key):\(localValue)"
    }
}

// MARK: - Codable

extension APIRequest: Codable where Model: Codable {

    private enum Keys: String, CodingKey {
        case config
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        config = try container.decode(APIRequestConfig.self, forKey: .config)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(config, forKey: .config)
    }
}

extension APIRequestConfig.QueryValue {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case ._array(let values):
            try container.encode(values)
        case .identifier(let key, let localValue):
            try container.encode(.identifierPlaceholderString(key: key, localValue: localValue))
        case ._value(let value):
            try container.encode(value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let values = try? container.decode([APIRequestConfig.QueryValue].self) {
            self = ._array(values)
        } else {
            let value = try container.decode(String.self)
            if let placeholder = value.toIdentifierPlaceholder {
                self = .identifier(key: placeholder.key, localValue: placeholder.localValue)
            } else {
                self = ._value(value)
            }
        }
    }
}

extension APIRequestConfig.Path {

    private init(from string: String) {
        var path: APIRequestConfig.Path?
        for component in string.split(separator: "/") {
            let child: APIRequestConfig.Path
            let component = String(component)
            if let placeholder = component.toIdentifierPlaceholder {
                child = .identifier(key: placeholder.key, localValue: placeholder.localValue)
            } else {
                child = .component(component)
            }
            if let parent = path {
                path = .path(parent: parent, child: child)
            } else {
                path = child
            }
        }
        self = path ?? .component(String())
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(from: try container.decode(String.self))
    }
}

// MARK: - QueryValue Conversion

public extension Bool {

    var queryValue: APIRequestConfig.QueryValue {
        return ._value(description)
    }
}

// MARK: - URL Encoding

extension APIRequestConfig.QueryValue {

    enum URLEncodingError: Error {
        case encodingFailed
        case missingIdentifier
        case nestedArraysAreNotSupported
    }
}

extension APIRequestConfig.QueryValue {

    public func encodedValue(for key: String,
                             with allowedCharacterSet: CharacterSet? = APIRequestConfig.QueryValue.allowedCharacterSet) throws -> String {

        let encodedKey = try encode(key, with: allowedCharacterSet)

        switch self {
        case ._value(let value):
            let encodedValue = try encode(value, with: allowedCharacterSet)
            return "\(encodedKey)=\(encodedValue)"
        case .identifier:
            throw URLEncodingError.missingIdentifier
        case ._array(let values):
            let encodedValues = try values.map { value -> String in
                switch value {
                case ._value(let value):
                    return try encode(value, with: allowedCharacterSet)
                case ._array:
                    throw URLEncodingError.nestedArraysAreNotSupported
                case .identifier:
                    throw URLEncodingError.missingIdentifier
                }
            }
            return encodedValues.map { "\(encodedKey)[]=\($0)" }.joined(separator: "&")
        }
    }

    private func encode(_ string: String, with allowedCharacterSet: CharacterSet?) throws -> String {
        guard let allowedCharacterSet = allowedCharacterSet else {
            return string
        }
        guard let string = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) else {
            throw URLEncodingError.encodingFailed
        }
        return string
    }
}

extension APIRequestConfig.QueryValue {

    public static let allowedCharacterSet: CharacterSet = {
        // https://tools.ietf.org/html/rfc3986#section-2.2
        let reservedCharacterSet = CharacterSet(charactersIn: ":/?#[]@!$&'()+,;=")
        let urlQueryAllowedCharacterSet = CharacterSet.urlQueryAllowed
        return urlQueryAllowedCharacterSet.subtracting(reservedCharacterSet)
    }()
}

extension APIRequestConfig.Body {

    public enum EncodingError: Error {
        case utf8Encoding
        case formURLEncoding(Error)
    }

    public var rawData: Data? {
        switch self {
        case .raw(let data):
            return data

        case ._formURLEncoded:
            return nil
        }
    }
}

// MARK: - Codable

extension APIRequestConfig.Body {

    private enum FormatType: String, Codable {
        case raw
        case formURLEncoded
    }

    private enum Keys: String, CodingKey {
        case formatType
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let type = try container.decode(FormatType.self, forKey: .formatType)

        switch type {
        case .raw:
            self = .raw(try container.decode(Data.self, forKey: .data))
        case .formURLEncoded:
            self = .formURLEncoded(try container.decode(OrderedDictionary.self, forKey: .data))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        switch self {
        case .raw(let data):
            try container.encode(data, forKey: .data)
            try container.encode(FormatType.raw, forKey: .formatType)
        case ._formURLEncoded(let data):
            try container.encode(data, forKey: .data)
            try container.encode(FormatType.formURLEncoded, forKey: .formatType)
        }
    }
}

// MARK: - Conversions

extension APIError {

    init(network error: NSError) {
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet:
                self = .internetConnectionFailure(error)
            case NSURLErrorTimedOut:
                self = .internetConnectionFailure(error)
            case NSURLErrorNetworkConnectionLost:
                self = .internetConnectionFailure(error)
            default:
                self = .network(error)
            }
        } else {
            self = .network(error)
        }
    }
}

extension APIRequestConfig.Path {

    public var description: String {
        switch self {
        case .component(let value):
            return value
        case .identifier(let key, let localValue):
            return .identifierPlaceholderString(key: key, localValue: localValue)
        case .path(let lhs, let rhs):
            return "\(lhs.description)/\(rhs.description)"
        }
    }

    public var debugDescription: String {
        return description
    }
}

// MARK: - JSON Encoder/Decoder

extension APIJSONCoderConfig {

    public var encoder: JSONEncoder {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.keyEncodingStrategy = keyEncodingStrategy
        jsonEncoder.set(context: .payload)
        if let dateEncodingStrategy = dateEncodingStrategy {
            jsonEncoder.dateEncodingStrategy = dateEncodingStrategy
        }
        return jsonEncoder
    }

    public var decoder: JSONDecoder {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = keyDecodingStrategy
        jsonDecoder.set(context: .payload)
        if let dateDecodingStrategy = dateDecodingStrategy {
            jsonDecoder.dateDecodingStrategy = dateDecodingStrategy
        }
        return jsonDecoder
    }

    /// Default `JSONEncoder`
    public static var defaultJSONEncoder: JSONEncoder {
        return APIJSONCoderConfig().encoder
    }

    /// Default `JSONDecoder`
    public static var defaultJSONDecoder: JSONDecoder {
        return APIJSONCoderConfig().decoder
    }
}

// MARK: - Content Types

extension APIRequest {

    public mutating func set(contentType: HTTPContentType) {
        config.headers["Content-Type"] = contentType.rawValue
    }

    public mutating func set<T: Encodable>(body data: T, jsonEncoder: JSONEncoder = APIJSONCoderConfig.defaultJSONEncoder) {
        do {
            set(contentType: .json)
            config.body = .raw(try jsonEncoder.encode(data))
        } catch {
            Logger.log(.error, "\(APIRequest.self): Could not encode body to JSON: \(data): \(error)", assert: true)
        }
    }
}

// MARK: - URLRequest

extension APIRequestConfig {

    func urlRequest(host: String,
                    queryEncoder: (OrderedDictionary<String, QueryValue>) throws -> String,
                    bodyEncoder: (APIRequestConfig.Body) throws -> Data) -> URLRequest? {

        guard var queryString = try? queryEncoder(query) else {
            Logger.log(.error, "\(APIRequestConfig.self): Could not URL-encode query dictionary", assert: true)
            return nil
        }
        if !queryString.isEmpty {
            queryString = "?" + queryString
        }
        guard let url = URL(string: host + "/" + path.description + queryString) else {
            return nil
        }
        var urlRequest = URLRequest(url: url)
        for (key, value) in headers.orderedKeyValues {
            urlRequest.setValue("\(value)", forHTTPHeaderField: key)
        }
        urlRequest.httpMethod = method.rawValue.uppercased()
        if let body = body {
            do {
                urlRequest.httpBody = try bodyEncoder(body)
            } catch {
                Logger.log(.error, "\(APIRequestConfig.self): Could not encode body: \(error)", assert: true)
            }
        }
        if let timeoutInterval = timeoutInterval {
            urlRequest.timeoutInterval = timeoutInterval
        }
        return urlRequest
    }
}

// MARK: - Status Code

extension HTTPURLResponse {

    var isSuccess: Bool {
        switch statusCode {
        case 200..<300, 304:
            return true
        default:
            return false
        }
    }
}

// MARK: - NetworkClient

public protocol NetworkClient {

    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

extension URLSession: NetworkClient {}

// MARK: - Equatable

extension APIError {

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.networkingProtocolIsNotHTTP, .networkingProtocolIsNotHTTP),
             (.network, .network),
             (.url, .url),
             (.deserialization, .deserialization),
             (.emptyBodyResponse, .emptyBodyResponse),
             (.sessionKeyMismatch, .sessionKeyMismatch):
            return true
        case (.internetConnectionFailure(let lhs), .internetConnectionFailure(let rhs)):
            return lhs as NSError == rhs as NSError
        case (.api(let lHTTPStatusCode, let lErrorPayload), .api(let rHTTPStatusCode, let rErrorPayload)):
            guard lHTTPStatusCode == rHTTPStatusCode else { return false }
            guard lErrorPayload == rErrorPayload else { return false }
            return true
        case (.networkingProtocolIsNotHTTP, _),
             (.network, _),
             (.url, _),
             (.deserialization, _),
             (.emptyBodyResponse, _),
             (.sessionKeyMismatch, _),
             (.internetConnectionFailure, _),
             (.api, _):
            return false
        }
    }
}

extension APIRequestConfig.Path {
    public static func == (_ lhs: APIRequestConfig.Path, _ rhs: APIRequestConfig.Path) -> Bool {
        return lhs.description == rhs.description
    }
}

// MARK: - Hashable

extension APIRequestConfig.Path {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }
}

// MARK: - Syntactic sugar

public extension RemoteIdentifier {
    var queryValue: APIRequestConfig.QueryValue {
        switch value {
        case .local(let value):
            return .identifier(key: identifierTypeID, localValue: value.description)
        case .remote(let value, _):
            return ._value(value.description)
        }
    }

    var pathComponent: APIRequestConfig.Path {
        switch value {
        case .local(let value):
            return .identifier(key: identifierTypeID, localValue: value.description)
        case .remote(let value, _):
            return .component(value.description)
        }
    }
}

public extension APIRequestConfig.Path {
    static func path(_ component: String) -> APIRequestConfig.Path {
        return .component(component)
    }
}

public func / (_ lhs: APIRequestConfig.Path, _ rhs: APIRequestConfig.Path) -> APIRequestConfig.Path {
    return .path(parent: lhs, child: rhs)
}

public func / (_ lhs: APIRequestConfig.Path, _ rhs: String) -> APIRequestConfig.Path {
    return lhs / .component(rhs)
}

public func / <ID>(_ lhs: APIRequestConfig.Path, _ rhs: ID) -> APIRequestConfig.Path where ID: RemoteIdentifier {
    return lhs / rhs.pathComponent
}

public func / <ID>(_ lhs: APIRequestConfig.Path, _ rhs: ID?) -> APIRequestConfig.Path where ID: RemoteIdentifier {
    guard let identifierComponent = rhs?.pathComponent else { return lhs }
    return lhs / identifierComponent
}

public extension HTTPMethod {

    var defaultQueueingStrategy: APIRequestConfig.QueueingStrategy {
        switch self {
        case .get,
             .head:
            return APIRequestConfig.QueueingStrategy(synchronization: .concurrent, retryOnInternetConnectionFailure: false)
        case .delete,
             .post,
             .put:
            return APIRequestConfig.QueueingStrategy(synchronization: .barrier, retryOnInternetConnectionFailure: true)
        }
    }

    var defaultBackground: Bool {
        switch self {
        case .get,
             .head:
            return false
        case .delete,
             .post,
             .put:
            return true
        }
    }
}

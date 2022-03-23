//
//  MetaClientQueueResponseHandler.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 1/11/21.
//

import Meta
import LucidCodeGenCore

struct MetaClientQueueResponseHandler {

    let descriptions: Descriptions

    init?(descriptions: Descriptions) throws {

        guard try descriptions.endpointsWithMergeableIdentifiers().isEmpty == false else { return nil }

        self.descriptions = descriptions
    }

    func imports() -> [Import] {
        return [
            .combine,
            .lucid
        ]
    }

    func meta() throws -> [FileBodyMember] {
        return [
            classComment,
            try responseHandlerClass(),
            EmptyLine()
        ]
    }

    private var classComment: PlainCode {
        return PlainCode(code: """
        /// When subclassing this to add custom functionality, it is essential to call:
        ///    super.clientQueue(clientQueue, didReceiveResponse: result, for: request)
        ///
        /// Failing to do so will result in newly created objects not merging the remote identifiers
        /// with the local values and creating duplicate entries on the device.
        """)
    }

    private func responseHandlerClass() throws -> FileBodyMember {

        return Type(identifier: TypeIdentifier(name: "RootClientQueueResponseHandler"))
            .with(kind: .class(final: false))
            .adding(inheritedType: TypeIdentifier(name: "CoreManagerContainerClientQueueResponseHandler"))
            .with(accessLevel: .open)
            .adding(members: [
                EmptyLine(),
                Property(variable: Variable(name: "managers")
                    .with(type: .optional(wrapped: .named("CoreManagerContainer")))
                    .with(kind: .weak)
                    .with(immutable: false))
                    .with(accessLevel: .public),
                EmptyLine(),
                Property(variable: Variable(name: "cancellable"))
                    .with(accessLevel: .private)
                    .with(value: Value.reference(
                        Reference.named("CancellableBox") | .call(Tuple())
                    )),
                EmptyLine(),
                Property(variable: Variable(name: "identifierDecoder")
                    .with(type: .jsonDecoder))
                    .with(accessLevel: .public)
                    .with(static: true)
                    .with(value: Value.reference(Reference.block(
                        FunctionBody()
                            .adding(members: [
                                Assignment(
                                    variable: Variable(name: "decoder"),
                                    value: Value.reference(Reference.named("JSONDecoder") | .call(Tuple()))
                                ),
                                Reference.named("decoder") + .named("set") | .call(Tuple()
                                    .adding(parameter: TupleParameter(name: "context", value: +.named("clientQueueRequest")))
                                ),
                                Return(value: Reference.named("decoder"))
                            ])
                        ) | .call(Tuple()))
                    ),
            ])
            .adding(members: [
                EmptyLine(),
                initializer(),
                EmptyLine(),
                clientQueueFunction(),
                EmptyLine(),
                try mergeIdentifiers()
            ])
            .adding(members: try descriptions.endpointsWithMergeableIdentifiers().flatMap { writeEndpoint -> [TypeBodyMember] in
                return [
                    EmptyLine(),
                    try mergeEntityIdentifier(writeEndpoint)
                ]
            })
    }

    private func initializer() -> TypeBodyMember {
        return Function(kind: .`init`)
            .with(accessLevel: .public)
            .adding(member: Assignment(variable: Reference.named("managers"), value: Value.nil))
    }

    private func clientQueueFunction() -> TypeBodyMember {
        return PlainCode(code: """
        open func clientQueue(_ clientQueue: APIClientQueuing,
                              didReceiveResponse result: APIClientQueueResult<Data, APIError>,
                              for request: APIClientQueueRequest) {

            mergeIdentifiers(clientQueue: clientQueue,
                             result: result,
                             request: request)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                    Logger.log(.error, \"\\(RootClientQueueResponseHandler.self): Identifier merge failed with error \\(error) for request \\(request) with result \\(result).\")
                    case .finished:
                        break
                    }
                }, receiveValue: { _ in })
                .store(in: cancellable)
        }
        """)
    }

    private func mergeIdentifiers() throws -> TypeBodyMember {

        return Function(kind: .named("mergeIdentifiers"))
            .with(accessLevel: .private)
            .adding(parameters: [
                FunctionParameter(name: "clientQueue", type: TypeIdentifier(name: "APIClientQueuing")),
                FunctionParameter(name: "result", type: TypeIdentifier(name: "APIClientQueueResult<Data, APIError>")),
                FunctionParameter(name: "request", type: TypeIdentifier(name: "APIClientQueueRequest"))
            ])
            .with(resultType: TypeIdentifier(name: "AnyPublisher<Void, Never>"))
            .adding(members: [
                EmptyLine(),
                Guard(assignment: Assignment(
                    variable: Variable(name: "managers"),
                    value: Reference.named("managers")
                )).adding(member:
                    Return(value: Reference.named("Just<Void>") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: Reference.named("()")))) +
                            Reference.named("eraseToAnyPublisher") | .call(Tuple())
                    )
                ),
                EmptyLine(),
                PlainCode(code: """
                switch (request.wrapped.config.path.normalizedString, request.wrapped.config.method) {
                \(try descriptions.endpointsWithMergeableIdentifiers().compactMap { endpoint -> String in
                    guard let writePayload = endpoint.writePayload else {
                        throw CodeGenError.endpointRequiresAtLeastOnePayload(endpoint.name)
                    }
                    let httpMethod = writePayload.httpMethod ?? ReadWriteEndpointPayload.HTTPMethod.defaultWrite
                    let managerName = "\(writePayload.entity.entityName.camelCased().suffixedName().variableCased())Manager"

                    return """
                    case ("\(endpoint.normalizedPathName)", .\(httpMethod.rawValue)):
                        return merge\(endpoint.transformedName)Identifiers(clientQueue: clientQueue, result: result, request: request, coreManager: managers.\(managerName))
                    """
                }.joined(separator: "\n"))
                default:
                    return Just<Void>(()).eraseToAnyPublisher()
                }
                """)
            ])
    }

    private func mergeEntityIdentifier(_ endpoint: EndpointPayload) throws -> TypeBodyMember {

        guard let writePayload = endpoint.writePayload else {
            throw CodeGenError.endpointRequiresAtLeastOnePayload(endpoint.name)
        }

        let entity = try descriptions.entity(for: writePayload.entity.entityName)

        return Function(kind: .named("merge\(endpoint.transformedName)Identifiers"))
            .with(accessLevel: .private)
            .adding(parameter: FunctionParameter(name: "clientQueue", type: TypeIdentifier(name: "APIClientQueuing")))
            .adding(parameter: FunctionParameter(name: "result", type: TypeIdentifier(name: "APIClientQueueResult<Data, APIError>")))
            .adding(parameter: FunctionParameter(name: "request", type: TypeIdentifier(name: "APIClientQueueRequest")))
            .adding(parameter: FunctionParameter(name: "coreManager", type: TypeIdentifier(name: "CoreManaging<\(entity.typeID().swiftString), AppAnyEntity>")))
            .with(resultType: TypeIdentifier(name: "AnyPublisher<Void, Never>"))
            .adding(member:
                PlainCode(code: """

                guard let identifiersData = request.identifiers,
                      let localIdentifiers = try? RootClientQueueResponseHandler.identifierDecoder.decode([\(entity.identifierTypeID().swiftString)].self, from: identifiersData) else {
                        Logger.log(.error, \"\\(RootClientQueueResponseHandler.self): Expected a \(entity.name.camelCased().variableCased()) identifier to be stored in \\(request).\", assert: true)
                        return Just<Void>(()).eraseToAnyPublisher()
                }

                switch result {
                case .success(let response):
                    let payloadDecoder = response.jsonCoderConfig.decoder
                    do {
                        let writePayload = try payloadDecoder.decode(\(try endpoint.typeID(for: writePayload).swiftString).self, from: response.data)
                        let publishers: [AnyPublisher<Void, Never>] = writePayload.\(entity.name.camelCased().variableCased().pluralName).enumerated().map { index, \(entity.name.camelCased().variableCased()) in
                            Logger.log(.debug, \"\\(RootClientQueueResponseHandler.self): Set \(entity.name.camelCased().variableCased()): \\(\(entity.name.camelCased().variableCased()).identifier)\")
                            \(entity.name.camelCased().variableCased()).merge(identifier: localIdentifiers[index])
                            clientQueue.merge(with: \(entity.name.camelCased().variableCased()).identifier)
                            return coreManager.setAndUpdateIdentifierInLocalStores(\(entity.name.camelCased().variableCased()), originTimestamp: request.timestamp)
                        }
                        return Publishers.MergeMany(publishers).eraseToAnyPublisher()
                    } catch {
                        Logger.log(.error, \"\\(RootClientQueueResponseHandler.self): Failed to deserialize \\(\(try endpoint.typeID(for: writePayload).swiftString).self): \\(error)\", assert: true)
                        return Just<Void>(()).eraseToAnyPublisher()
                    }
                case .aborted:
                    Logger.log(.error, \"\\(RootClientQueueResponseHandler.self): Create \(entity.name.camelCased().variableCased()) aborted.\")
                    return Just<Void>(()).eraseToAnyPublisher()
                case .failure(let error):
                    Logger.log(.error, \"\\(RootClientQueueResponseHandler.self): Failed to create \(entity.name.camelCased().variableCased()): \\(error).\")
                    let publishers: [AnyPublisher<Void, Never>] = localIdentifiers.map { localIdentifier in
                        return coreManager.removeFromLocalStores(localIdentifier, originTimestamp: request.timestamp)
                    }
                    return Publishers.MergeMany(publishers).eraseToAnyPublisher()
                }
                """)
            )
    }
}



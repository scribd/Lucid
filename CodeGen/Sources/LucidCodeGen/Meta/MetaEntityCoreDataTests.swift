//
//  MetaEntityCoreDataTests.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/16/19.
//

import Meta
import LucidCodeGenCore

struct MetaEntityCoreDataTests {

    let entityName: String

    let descriptions: Descriptions

    func imports() -> [Import] {
        return [
            .xcTest,
            .lucid,
            .app(descriptions, testable: true),
            .lucidTestKit,
            .appTestKit(descriptions)
        ]
    }

    func meta() throws -> Type {
        let entity = try descriptions.entity(for: entityName)
        let identifierTypeID = entity.identifierTypeID().swiftString
        let identifierValueTypeID = try entity.remoteIdentifierValueTypeID(descriptions).reference.swiftString
        let entityParameters: String = {
            if entity.hasVoidIdentifier {
                return "()"
            }
            if entity.hasToManyRelationshipIdentifier, let relationship = identifierRelationshipEntity() {
                return "(42, identifierRelationship: .\(relationship.name.camelCased().variableCased()))"
            }
            return "(42)"
        }()
        let identifierAssertion: String = {
            if entity.hasVoidIdentifier {
                return "XCTAssertEqual(result.entity?.identifier, \(identifierTypeID)())"
            }
            if entity.identifier.isRelationship, let relationship = identifierRelationshipEntity() {
                return "XCTAssertEqual(result.entity?.identifier, \(identifierTypeID)(value: .remote(\(identifierValueTypeID)(42), nil), identifierTypeID: \(MetaCode(meta: relationship.typeID().reference + .named("identifierTypeID")))))"
            }
            return "XCTAssertEqual(result.entity?.identifier, \(identifierTypeID)(value: .remote(\(identifierValueTypeID)(42), nil)))"
        }()

        return Type(identifier: TypeIdentifier(name: "\(entity.transformedName)CoreDataTests"))
            .adding(inheritedType: .xcTestCase)
            .adding(member: PlainCode(code: """

            private var store: \(MetaCode(meta: TypeIdentifier.coreDataStore(of: entity.typeID()).with(implicitUnwrap: true)))

            override func setUp() {
                super.setUp()

                LucidConfiguration.logger = LoggerMock()
                store = CoreDataStore(coreDataManager: CoreDataManager(modelName: "\(descriptions.targets.app.moduleName)",
                                                                       in: Bundle(for: CoreManagerContainer.self),
                                                                       storeType: .memory))
            }

            override func tearDown() {
                defer { super.tearDown() }

                store = nil
                LucidConfiguration.logger = nil
            }

            // MARK: - Tests

            """))
            .adding(member: Function(kind: .named("test_\(entity.name)_should_be_stored_then_restored_from_core_data"))
                .adding(member: PlainCode(code: """
                let expectation = self.expectation(description: "\(entity.name)")
                let initialEntity = \(MetaCode(meta: entity.factoryTypeID.reference))\(entityParameters).entity

                store.set(initialEntity, in: WriteContext(dataTarget: .local)) { result in
                    guard let result = result else {
                        XCTFail("Unexpectedly received nil.")
                        return
                    }

                    switch result {
                    case .success(let entity):

                        self.store.get(byID: entity.identifier, in: _ReadContext<EndpointResultPayload>()) { result in
                            switch result {
                            case .success(let result):
                \(entity.remote ? MetaCode(indentation: 4, meta: Reference.named("XCTAssertEqual") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: .named("result.entity") | .unwrap + .named("identifier") + .named("remoteSynchronizationState")))
                        .adding(parameter: TupleParameter(value: .named("initialEntity") + .named("identifier") + .named("remoteSynchronizationState")))
                    )).description : "")
                \(MetaCode(indentation: 4, meta: entity.valuesThenRelationships.compactMap { property in
                    return Reference.named("XCTAssertEqual") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: .named("result.entity") | .unwrap + .named(property.transformedName())))
                        .adding(parameter: TupleParameter(value: .named("initialEntity") + .named(property.transformedName())))
                    )
                }))
                                \(identifierAssertion)

                            case .failure(let error):
                                XCTFail("Unexpected error: \\(error).")
                            }
                            expectation.fulfill()
                        }

                    case .failure(let error):
                        XCTFail("Unexpected error: \\(error).")
                        expectation.fulfill()
                    }
                }

                wait(for: [expectation], timeout: 1)
                """)
            ))
    }

    private func identifierRelationshipEntity() -> Entity? {
        guard let entity = try? descriptions.entity(for: entityName) else { return nil }

        if entity.identifier.isRelationship,
           case .relationships(_, let ids) = entity.identifier.identifierType,
           let relationships: [Entity] = try? ids.lazy.map({ try descriptions.entity(for: $0.entityName) }).sorted(by: { $0.name < $1.name }),
           let defaultRelationship: Entity = relationships.first {
            return defaultRelationship
        }

        return nil
    }
}

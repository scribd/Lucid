//
//  MetaEndpointWritePayloadTests.swift
//  LucidCodeGen
//
//  Created by Stephane Magne on 1/14/21.
//

import Meta
import LucidCodeGenCore

struct MetaEndpointWritePayloadTests {

    private typealias TestCombination = (
        test: EndpointPayloadTest,
        context: String,
        entity: EndpointPayloadTest.Entity
    )

    let endpointName: String

    let tests: [EndpointPayloadTest]

    let writePayload: ReadWriteEndpointPayload

    let descriptions: Descriptions

    init?(endpointName: String,
          descriptions: Descriptions) throws {

        let endpoint = try descriptions.endpoint(for: endpointName)
        let writeTests = endpoint.tests?.writeTests ?? []

        guard writeTests.isEmpty == false,
              let writePayloadValue = endpoint.writePayload else {
            return nil
        }

        self.endpointName = endpointName
        self.tests = writeTests
        self.writePayload = writePayloadValue
        self.descriptions = descriptions
    }

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
        let endpoint = try descriptions.endpoint(for: endpointName)
        let testCombinations = try self.testCombinations()

        let unexpectedEntities = testCombinations.filter { $0.entity.name != writePayload.entity.entityName }
        guard unexpectedEntities.isEmpty else {
            throw CodeGenError.endpointWriteTestsShouldOnlyTestForMainEntity(endpoint: endpoint.name, entity: writePayload.entity.entityName)
        }

        return Type(identifier: TypeIdentifier(name: "\(endpoint.transformedName)WritePayloadTests"))
            .adding(inheritedType: .xcTestCase)
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .named("setUp"))
                .with(override: true)
                .adding(member: .named(.super) + .named("setUp") | .call())
                .adding(member: Assignment(
                    variable: TypeIdentifier.logger.reference + .named("shared"),
                    value: Reference.named("LoggerMock") | .call()
                ))
            )
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .named("tearDown"))
                .with(override: true)
                .adding(member: Assignment(
                    variable: TypeIdentifier.logger.reference + .named("shared"),
                    value: Value.nil
                ))
                .adding(member: .named(.super) + .named("tearDown") | .call())
            )
            .adding(member: EmptyLine())
            .adding(member: Comment.mark("Payloads"))
            .adding(member: EmptyLine())
            .adding(members: tests.map { test in
                Property(variable: Variable(name: "\(endpoint.testJSONResourceName(for: test).variableCased())")
                    .with(kind: .lazy)
                    .with(immutable: false)
                    .with(type: .data))
                    .with(accessLevel: .private)
                    .with(value: FunctionBody()
                        .adding(member: Guard(assignment: Assignment(
                            variable: Variable(name: "data"),
                            value: .named("JSONPayloadFactory") + .named("jsonPayload") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "named", value: Value.string(endpoint.testJSONResourceName(for: test))))
                            )
                        ))
                            .adding(member: .named("XCTFail") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: Value.string("Could not read \(endpoint.testJSONResourceName(for: test)).json")))
                            ))
                            .adding(member: Return(value: TypeIdentifier.data.reference | .call()))
                        )
                        .adding(member: Return(value: Reference.named("data")))
                        .with(tuple: Tuple())
                    )
            })
            .adding(member: EmptyLine())
            .adding(member: Comment.mark("Tests"))
            .adding(members: try testCombinations.flatMap { (test, endpointName, entity) -> [TypeBodyMember] in
                let assert: Reference = entity.count.flatMap {
                    return Reference.named("XCTAssertEqual") | .call(Tuple()
                        .adding(parameter: TupleParameter(value: .named("endpointResult") + .named(entity.name.camelCased().variableCased().pluralName) + .named("array") + .named("count")))
                        .adding(parameter: TupleParameter(value: Value.int($0)))
                    )
                } ?? Reference.named("XCTAssertFalse") | .call(Tuple()
                    .adding(parameter: TupleParameter(value: .named("endpointResult") + .named(entity.name.camelCased().variableCased().pluralName) + .named("isEmpty")))
                )

                let function = Function(kind: .named("test_\(test.name)_\(endpointName.camelCased(separators: "_/").snakeCased)_\(entity.name)"))
                    .adding(member: Do(body: [
                        Assignment(
                            variable: Variable(name: "endpointResult"),
                            value: .try | .named("APIJSONCoderConfig") + .named("defaultJSONDecoder") + .named("decode") | .call(Tuple()
                                .adding(parameter: TupleParameter(value: try endpoint.typeID(for: writePayload).reference + .named(.`self`)))
                                .adding(parameter: TupleParameter(name: "from", value: Reference.named(endpoint.testJSONResourceName(for: test).variableCased())))
                            )
                        ),
                        assert
                    ], catch: Catch()
                        .adding(member: Reference.named("XCTFail") | .call(Tuple()
                            .adding(parameter: TupleParameter(value: Value.string("Unexpected error: \\(error).")))
                        ))
                    ))

                return [EmptyLine(), function]
            })
    }

    private func testCombinations() throws -> [TestCombination] {
        return tests.flatMap { test in
            return test.endpoints.flatMap { endpointName in
                return test.entities.map { entity in
                    return (test, endpointName, entity)
                }
            }
        }
    }
}

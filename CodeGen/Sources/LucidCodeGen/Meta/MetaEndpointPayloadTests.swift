//
//  MetaEndpointPayloadTests.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/12/19.
//

import Meta
import LucidCodeGenCore

struct MetaEndpointPayloadTests {
    
    private typealias TestCombination = (
        test: EndpointPayloadTest,
        context: String,
        entity: EndpointPayloadTest.Entity
    )
    
    let endpointName: String
    
    let descriptions: Descriptions

    let reactiveKit: Bool
    
    func imports() -> [Import] {
        return [
            .xcTest,
            .lucid(reactiveKit: reactiveKit),
            .app(descriptions, testable: true),
            .lucidTestKit(reactiveKit: reactiveKit),
            .appTestKit(descriptions)
        ]
    }
    
    func meta() throws -> Type {
        let endpoint = try descriptions.endpoint(for: endpointName)
        let testCombinations = try self.testCombinations()
        return Type(identifier: TypeIdentifier(name: "\(endpoint.transformedName)PayloadTests"))
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
            .adding(members: endpoint.tests.map { test in
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
            .adding(members: testCombinations.flatMap { (test, endpointName, entity) -> [TypeBodyMember] in
                
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
                            value: .try | .named("EndpointResultPayload") | .call(Tuple()
                                .adding(parameter: TupleParameter(name: "from", value: Reference.named(endpoint.testJSONResourceName(for: test).variableCased())))
                                .adding(parameter: TupleParameter(name: "endpoint", value: +.named(endpointName.camelCased(separators: "_/").variableCased())))
                                .adding(parameter: TupleParameter(name: "decoder", value: .named("APIJSONCoderConfig") + .named("defaultJSONDecoder")))
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
        let endpoint = try descriptions.endpoint(for: endpointName)
        return endpoint.tests.flatMap { test in
            return test.endpoints.flatMap { endpointName in
                return test.entities.map { entity in
                    return (test, endpointName, entity)
                }
            }
        }
    }
}

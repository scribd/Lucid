//
//  MetaEntityFactories.swift
//  LucidCodeGen
//
//  Created by Théophane Rupin on 4/16/19.
//

import Meta
import LucidCodeGenCore

struct MetaEntityFactories {
    
    let descriptions: Descriptions
    
    func meta() -> [FileBodyMember] {
        return [
            entityFactory(),
            EmptyLine(),
            jsonPayloadFactory()
        ]
    }
    
    private func entityFactory() -> Type {
        return Type(identifier: TypeIdentifier(name: "EntityFactory"))
            .adding(member: EmptyLine())
            .adding(member: Function(kind: .named("reset"))
                .with(accessLevel: .public)
                .with(static: true)
                .adding(members: descriptions.entities
                    .filter { $0.remote }
                    .filter { $0.hasVoidIdentifier == false }
                    .map { entity in
                        entity.factoryTypeID.reference + .named("resetIdentifier") | .call()
                    }
                )
            )
    }
    
    private func jsonPayloadFactory() -> PlainCode {
        return PlainCode(code: """
        public final class JSONPayloadFactory {

            private static let bundle = Bundle(for: JSONPayloadFactory.self)

            public static func jsonPayload(named resourceName: String) -> Data? {
                let path = bundle.path(forResource: resourceName, ofType: "json")

                guard let filePath = path else {
                    return nil
                }

                return (try? String(contentsOfFile: filePath))?.data(using: .utf8)
            }
        }
        """)
    }
}


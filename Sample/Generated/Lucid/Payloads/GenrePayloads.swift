//
// GenrePayloads.swift
//
// Generated automatically.
// Copyright © Scribd. All rights reserved.
//

import Lucid

final class GenrePayload: ArrayConvertable {

    // identifier
    let id: Int

    // properties
    let name: String

    init(id: Int, name: String) {

        self.id = id
        self.name = name
    }
}

extension GenrePayload: PayloadIdentifierDecodableKeyProvider {

    static let identifierKey = "id"
    var identifier: GenreIdentifier {
        return GenreIdentifier(value: .remote(id, nil))
    }
}

// MARK: - Default Endpoint Payload

final class DefaultEndpointGenrePayload: Decodable, PayloadConvertable, ArrayConvertable {

    let rootPayload: GenrePayload
    let entityMetadata: Optional<VoidMetadata>

    private enum Keys: String, CodingKey {
        case id
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let rootPayload = GenrePayload(
            id: try container.decode(Int.self, forKey: .id, defaultValue: nil, logError: true),
            name: try container.decode(String.self, forKeys: [.name], defaultValue: nil, logError: true)
        )
        let entityMetadata = try FailableValue<VoidMetadata>(from: decoder).value()
        self.rootPayload = rootPayload
        self.entityMetadata = entityMetadata
    }
}

extension DefaultEndpointGenrePayload: PayloadIdentifierDecodableKeyProvider {

    static let identifierKey = GenrePayload.identifierKey
    var identifier: GenreIdentifier {
        return rootPayload.identifier
    }
}

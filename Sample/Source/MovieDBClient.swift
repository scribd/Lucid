//
//  MovieDBClient.swift
//  Sample
//
//  Created by Théophane Rupin on 6/12/20.
//  Copyright © 2020 Scribd. All rights reserved.
//

import Foundation
import Lucid

final class MovieDBClient: APIClient {
    
    let networkClient: NetworkClient

    let identifier = Constants.identifier
    
    let host = Constants.apiHost
    
    let deduplicator: APIRequestDeduplicating = APIRequestDeduplicator(label: Constants.identifier)
    
    init(networkClient: NetworkClient = URLSession.shared) {
        self.networkClient = networkClient
    }
}

// MARK: - Request Handling

extension MovieDBClient {
    
    func prepareRequest(_ requestConfig: APIRequestConfig, completion: @escaping (APIRequestConfig) -> Void) {
        var requestConfig = requestConfig
        requestConfig.query["api_key"] = .value(Constants.apiKey)
        completion(requestConfig)
    }
}

// MARK: - Error Handling

extension MovieDBClient {
    
    struct ErrorModel: Decodable {
        let statusCode: Int
        let statusMessage: String
    }

    func errorPayload(from body: Data) -> APIErrorPayload? {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let error = try jsonDecoder.decode(ErrorModel.self, from: body)
            return APIErrorPayload(apiStatusCode: error.statusCode, message: error.statusMessage)
        } catch {
            Logger.log(.error, "\(MovieDBClient.self): Could not decode error: \(error)", assert: true)
            return nil
        }
    }
}

// MARK: - Constants

extension MovieDBClient {
    
    enum Constants {
        fileprivate static let identifier = "MovieDB"
        fileprivate static let apiHost = "https://api.themoviedb.org/3"
        fileprivate static let apiKey = "1a6eb1225335bbb37278527537d28a5d"

        static let imageAPIHost = "https://image.tmdb.org/t/p/w1280"
    }
}

//
//  JSONPayloadsGenerator.swift
//  LucidCommand
//
//  Created by Théophane Rupin on 1/31/19.
//

import Foundation
import LucidCodeGen
import PathKit

#if os(Linux)
import FoundationNetworking
#endif

final class JSONPayloadsGenerator {
    
    private let outputPath: Path
    
    private let descriptions: Descriptions
    
    private let endpointFilter: Set<String>?
    
    private let urlSession: URLSession
    
    private let authToken: String?
    
    private let logger: Logger
    
    init(to outputPath: Path,
         descriptions: Descriptions,
         authToken: String?,
         endpointFilter: [String]?,
         logger: Logger,
         urlSession: URLSession = .shared) {

        self.outputPath = outputPath
        self.descriptions = descriptions
        self.endpointFilter = endpointFilter.flatMap { Set($0.map { $0.camelCased() }) }
        self.logger = logger
        self.urlSession = urlSession

        self.authToken = authToken?
            .data(using: .utf8)
            .flatMap { "Basic \($0.base64EncodedString())" }
    }
    
    func generate() throws {
        logger.moveToChild("Generating JSON Payloads")
        
        let dispatchGroup = DispatchGroup()
        for endpoint in descriptions.endpoints where !endpoint.tests.isEmpty && (endpointFilter?.contains(endpoint.name) ?? true) {

            for test in endpoint.tests {

                dispatchGroup.enter()
                
                urlSession.request(test.url, httpMethod: test.httpMethod, headers: ["Authorization": authToken], body: test.body, logger: logger) { json in
                    defer { dispatchGroup.leave() }
                    guard let json = json else { return }
                    let outputDirectory = self.outputPath + OutputDirectory.jsonPayloads(endpoint.transformedName).path(appModuleName: self.descriptions.targets.app.moduleName)
                    let outputFile = outputDirectory + "\(test.name.camelCased().capitalized)\(endpoint.transformedName.capitalized)Payload.json"
                    do {
                        try outputFile.parent().mkpath()
                        try outputFile.write(json)
                        self.logger.done("\(test.url.path) - (\(endpoint.name):\(test.name))")
                    } catch {
                        self.logger.error("\(test.url.path) - (\(endpoint.name):\(test.name)) -> \(error)")
                    }
                }
            }
        }
        
        let result = dispatchGroup.wait(timeout: .now() + .seconds(300))
        switch result {
        case .success:
            self.logger.moveToParent()
        case .timedOut:
            fatalError("Failed to complete all JSON payload requests in under 5 minutes. Check internet connection.")
        }
    }
}

private extension URLSession {
    
    func request(_ url: URL, httpMethod: EndpointPayloadTest.HTTPMethod, headers: [String: String?], body: String?, logger: Logger, completion: @escaping (String?) -> Void) {
        
        var request = URLRequest(url: url)

        request.httpMethod = httpMethod.rawValue.uppercased()
        
        for (key, value) in headers {
            guard let value = value else { continue }
            request.addValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = body.data(using: String.Encoding.utf8)
        }
        
        dataTask(with: request) { (data, response, error) in
        
            if let error = error {
                logger.error("\(url): \(error)")
                completion(nil)
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                logger.error("Response was expected to be of type \(HTTPURLResponse.self).")
                completion(nil)
                return
            }
            
            guard response.statusCode >= 200 && response.statusCode < 300 else {
                if let data = data,
                    let string = String(data: data, encoding: .utf8) {
                    logger.error("Error status code: \(response.statusCode). \(string)")
                } else {
                    logger.error("Error status code: \(response.statusCode). No body.")
                }
                completion(nil)
                return
            }
            
            guard let data = data else {
                logger.error("Could not find a body.")
                completion(nil)
                return
            }
            
            guard let contentType = response.allHeaderFields["Content-Type"] as? String, contentType.contains("application/json") else {
                logger.error("Invalid body.")
                completion(nil)
                return
            }

            guard let string = String(data: data, encoding: .utf8) else {
                logger.error("Non UTF-8 body.")
                completion(nil)
                return
            }
            
            completion(string)
        }.resume()
    }
}

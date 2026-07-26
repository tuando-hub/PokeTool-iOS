import Foundation

protocol NetworkTransporting {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class NetworkClient: NetworkTransporting {
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}

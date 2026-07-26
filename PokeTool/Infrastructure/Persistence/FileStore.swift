import Foundation

final class FileStore {
    private let rootURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        rootURL = applicationSupport.appendingPathComponent("PokeTool", isDirectory: true)
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func write<T: Encodable>(_ value: T, key: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: url(for: key), options: .atomic)
    }

    func read<T: Decodable>(_ type: T.Type, key: String) throws -> T {
        let data = try Data(contentsOf: url(for: key))
        return try decoder.decode(type, from: data)
    }

    private func url(for key: String) -> URL {
        let safeName = key.replacingOccurrences(of: "/", with: "_")
        return rootURL.appendingPathComponent(safeName).appendingPathExtension("json")
    }
}


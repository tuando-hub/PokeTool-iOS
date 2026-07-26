import Foundation

enum ManagedStorageError: Error {
    case invalidKey
    case invalidPath
    case outsideRoot
    case notFound
    case alreadyExists
    case tooLarge
    case serialization
    case io
}

struct ManagedFileInfo: Codable {
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date?
}

actor FileStore {
    private let rootURL: URL
    private let fileManager: FileManager
    private let maximumBytes: Int
    private var values: [String: JSONValue] = [:]
    private let keyValueURL: URL

    init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default,
        maximumBytes: Int = 8 * 1_024 * 1_024
    ) {
        self.fileManager = fileManager
        self.maximumBytes = maximumBytes
        let base = rootURL ?? fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("PokeTool", isDirectory: true)
        self.rootURL = base.standardizedFileURL
        self.keyValueURL = base.appendingPathComponent(".key-values.json")
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: keyValueURL),
           let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            values = decoded
        }
        for directory in ["data", "cache", "logs", "results", "temp", "downloads"] {
            try? fileManager.createDirectory(
                at: base.appendingPathComponent(directory, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    func get(_ key: String) throws -> JSONValue? {
        try validateKey(key)
        return values[key]
    }

    func set(_ key: String, value: JSONValue) throws {
        try validateKey(key)
        let size = try JSONEncoder().encode(value).count
        guard size <= 256 * 1_024 else { throw ManagedStorageError.tooLarge }
        values[key] = value
        try persistValues()
    }

    func remove(_ key: String) throws {
        try validateKey(key)
        values[key] = nil
        try persistValues()
    }
    func contains(_ key: String) throws -> Bool { try validateKey(key); return values[key] != nil }
    func keys(prefix: String?) -> [String] {
        values.keys.filter { key in
            guard let prefix else { return true }
            return key.hasPrefix(prefix)
        }.sorted()
    }
    func clear(prefix: String?) throws -> Int {
        let targets = keys(prefix: prefix)
        targets.forEach { values[$0] = nil }
        try persistValues()
        return targets.count
    }

    func read(_ path: String) throws -> Data {
        let url = try resolve(path)
        guard fileManager.fileExists(atPath: url.path) else { throw ManagedStorageError.notFound }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else { throw ManagedStorageError.tooLarge }
        return data
    }

    func write(_ path: String, data: Data, overwrite: Bool = false) throws {
        guard data.count <= maximumBytes else { throw ManagedStorageError.tooLarge }
        let url = try resolve(path)
        if fileManager.fileExists(atPath: url.path), !overwrite {
            throw ManagedStorageError.alreadyExists
        }
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    func exists(_ path: String) throws -> Bool {
        fileManager.fileExists(atPath: try resolve(path).path)
    }

    func info(_ path: String) throws -> ManagedFileInfo {
        let url = try resolve(path)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return ManagedFileInfo(
            path: path,
            isDirectory: attributes[.type] as? FileAttributeType == .typeDirectory,
            size: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
            modifiedAt: attributes[.modificationDate] as? Date
        )
    }

    func list(_ path: String) throws -> [ManagedFileInfo] {
        let url = try resolve(path)
        return try fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        ).prefix(1_000).map { item in
            let values = try item.resourceValues(
                forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            )
            let relative = String(item.path.dropFirst(rootURL.path.count))
            return ManagedFileInfo(
                path: relative, isDirectory: values.isDirectory ?? false,
                size: Int64(values.fileSize ?? 0), modifiedAt: values.contentModificationDate
            )
        }
    }

    func createDirectory(_ path: String) throws {
        try fileManager.createDirectory(at: resolve(path), withIntermediateDirectories: true)
    }

    func removePath(_ path: String) throws {
        let url = try resolve(path)
        guard fileManager.fileExists(atPath: url.path) else { throw ManagedStorageError.notFound }
        try fileManager.removeItem(at: url)
    }

    func move(_ source: String, to destination: String, overwrite: Bool) throws {
        let sourceURL = try resolve(source)
        let destinationURL = try resolve(destination)
        guard fileManager.fileExists(atPath: sourceURL.path) else { throw ManagedStorageError.notFound }
        try prepareDestination(destinationURL, overwrite: overwrite)
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    func copy(_ source: String, to destination: String, overwrite: Bool) throws {
        let sourceURL = try resolve(source)
        let destinationURL = try resolve(destination)
        guard fileManager.fileExists(atPath: sourceURL.path) else { throw ManagedStorageError.notFound }
        try prepareDestination(destinationURL, overwrite: overwrite)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    func temporaryFile(extension fileExtension: String?) throws -> String {
        let suffix = fileExtension?.filter { $0.isLetter || $0.isNumber }.prefix(12) ?? ""
        let name = UUID().uuidString + (suffix.isEmpty ? "" : ".\(suffix)")
        let path = "/temp/\(name)"
        try Data().write(to: resolve(path), options: .atomic)
        return path
    }

    func cleanupTemporary(olderThan date: Date) throws -> Int {
        let items = try list("/temp")
        let targets = items.filter { ($0.modifiedAt ?? .distantPast) < date }
        for item in targets { try? removePath(item.path) }
        return targets.count
    }

    func resetTransientState() { values.removeAll() }

    private func validateKey(_ key: String) throws {
        guard !key.isEmpty, key.count <= 256, !key.contains("\0") else {
            throw ManagedStorageError.invalidKey
        }
    }

    private func resolve(_ logicalPath: String) throws -> URL {
        guard logicalPath.hasPrefix("/"), logicalPath.count <= 512,
              !logicalPath.contains("\0"), !logicalPath.contains("\\"),
              !logicalPath.contains("://") else { throw ManagedStorageError.invalidPath }
        let components = logicalPath.split(separator: "/", omittingEmptySubsequences: true)
        guard let root = components.first.map(String.init),
              ["data", "cache", "logs", "results", "temp", "downloads"].contains(root) else {
            throw ManagedStorageError.invalidPath
        }
        var safe: [String] = []
        for component in components {
            if component == "." { continue }
            if component == ".." {
                guard safe.count > 1 else { throw ManagedStorageError.outsideRoot }
                safe.removeLast()
            } else {
                safe.append(String(component))
            }
        }
        let candidate = safe.reduce(rootURL) { $0.appendingPathComponent($1) }.standardizedFileURL
        guard candidate.path == rootURL.path || candidate.path.hasPrefix(rootURL.path + "/") else {
            throw ManagedStorageError.outsideRoot
        }
        let resolvedParent = candidate.deletingLastPathComponent().resolvingSymlinksInPath()
        let resolvedRoot = rootURL.resolvingSymlinksInPath()
        guard resolvedParent.path == resolvedRoot.path ||
                resolvedParent.path.hasPrefix(resolvedRoot.path + "/") else {
            throw ManagedStorageError.outsideRoot
        }
        return candidate
    }

    private func prepareDestination(_ url: URL, overwrite: Bool) throws {
        if fileManager.fileExists(atPath: url.path) {
            guard overwrite else { throw ManagedStorageError.alreadyExists }
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
    }

    private func persistValues() throws {
        let data = try JSONEncoder().encode(values)
        guard data.count <= maximumBytes else { throw ManagedStorageError.tooLarge }
        try data.write(to: keyValueURL, options: .atomic)
    }
}

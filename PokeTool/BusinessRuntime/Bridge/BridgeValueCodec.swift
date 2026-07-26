import Foundation

struct BridgeValueCodec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func decode<T: Decodable>(_ type: T.Type, from payload: JSONValue, method: String) throws -> T {
        do { return try decoder.decode(type, from: try encoder.encode(payload)) }
        catch {
            throw BridgeArgumentError(
                method: method, argument: "payload", expected: String(describing: type),
                received: payload.typeName
            )
        }
    }

    func encode<T: Encodable>(_ value: T) throws -> String {
        guard let string = String(data: try encoder.encode(value), encoding: .utf8) else {
            throw BrowserError.serializationFailed("Unable to encode bridge result")
        }
        return string
    }

    func encodeBrowserValue(_ value: BrowserValue) throws -> String {
        try encode(value)
    }
}

extension JSONValue {
    var typeName: String {
        switch self {
        case .string: return "string"
        case .number: return "number"
        case .bool: return "boolean"
        case .object: return "object"
        case .array: return "array"
        case .null: return "null"
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}

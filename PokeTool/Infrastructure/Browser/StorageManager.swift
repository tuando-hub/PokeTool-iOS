import Foundation
import WebKit

enum BrowserStorageState: String, Equatable {
    case unknown
    case clean
    case populated
    case clearing
    case unavailable
}

enum BrowserStorageScope: Equatable {
    case localStorage
    case sessionStorage
    case websiteData
    case cache
    case all
}

struct BrowserStorageSnapshot: Equatable {
    let state: BrowserStorageState
    let recordCount: Int
    let dataTypes: Set<String>
}

@MainActor
final class StorageManager {
    private let browserId: BrowserID
    private let websiteDataStore: WKWebsiteDataStore
    private let eventEmitter: BrowserEventEmitter
    private let logger: Logging

    private(set) var state: BrowserStorageState = .unknown

    init(
        browserId: BrowserID,
        websiteDataStore: WKWebsiteDataStore,
        eventEmitter: BrowserEventEmitter,
        logger: Logging
    ) {
        self.browserId = browserId
        self.websiteDataStore = websiteDataStore
        self.eventEmitter = eventEmitter
        self.logger = logger
    }

    func inspect() async -> BrowserStorageSnapshot {
        let records = await dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        let types = records.reduce(into: Set<String>()) { result, record in
            result.formUnion(record.dataTypes)
        }
        updateState(records.isEmpty ? .clean : .populated)
        return BrowserStorageSnapshot(state: state, recordCount: records.count, dataTypes: types)
    }

    func clear(_ scope: BrowserStorageScope) async {
        updateState(.clearing)
        let dataTypes = types(for: scope)
        await removeData(ofTypes: dataTypes)
        let snapshot = await inspect()
        logger.log(
            .debug,
            category: .storage,
            message: "Browser storage cleared",
            metadata: [
                "browserId": browserId.description,
                "remainingRecords": String(snapshot.recordCount)
            ]
        )
    }

    private func types(for scope: BrowserStorageScope) -> Set<String> {
        switch scope {
        case .localStorage:
            return [WKWebsiteDataTypeLocalStorage]
        case .sessionStorage:
            return [WKWebsiteDataTypeSessionStorage]
        case .websiteData, .all:
            return WKWebsiteDataStore.allWebsiteDataTypes()
        case .cache:
            return [
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeMemoryCache
            ]
        }
    }

    private func dataRecords(ofTypes types: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { continuation in
            websiteDataStore.fetchDataRecords(ofTypes: types) {
                continuation.resume(returning: $0)
            }
        }
    }

    private func removeData(ofTypes types: Set<String>) async {
        await withCheckedContinuation { continuation in
            websiteDataStore.removeData(
                ofTypes: types,
                modifiedSince: .distantPast
            ) {
                continuation.resume()
            }
        }
    }

    private func updateState(_ state: BrowserStorageState) {
        self.state = state
        eventEmitter.emit(.storageChanged(browserId, state))
    }
}

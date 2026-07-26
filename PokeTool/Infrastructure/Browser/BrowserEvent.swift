import Foundation

enum BrowserEvent {
    case created(BrowserID)
    case destroyed(BrowserID)
    case stateChanged(BrowserID, BrowserState)
    case navigationStarted(BrowserID, URL?)
    case navigationCommitted(BrowserID, URL?)
    case navigationFinished(BrowserID, URL?)
    case navigationFailed(BrowserID, BrowserError)
    case loadingStarted(BrowserID)
    case loadingFinished(BrowserID, TimeInterval)
    case historyChanged(BrowserID, Int)
    case cookiesChanged(BrowserID, Int)
    case storageChanged(BrowserID, BrowserStorageState)
    case downloadStarted(BrowserID, BrowserDownloadID)
    case downloadFinished(BrowserID, BrowserDownloadID)
    case downloadFailed(BrowserID, BrowserDownloadID, BrowserError)
    case webProcessTerminated(BrowserID)

    var platformEvent: PlatformEvent {
        switch self {
        case .created(let id):
            return make("browser.created", id)
        case .destroyed(let id):
            return make("browser.destroyed", id)
        case .stateChanged(let id, let state):
            return make("browser.state.changed", id, ["state": state.rawValue])
        case .navigationStarted(let id, let url):
            return make("browser.navigation.started", id, urlAttributes(url))
        case .navigationCommitted(let id, let url):
            return make("browser.navigation.committed", id, urlAttributes(url))
        case .navigationFinished(let id, let url):
            return make("browser.navigation.finished", id, urlAttributes(url))
        case .navigationFailed(let id, let error):
            return make("browser.navigation.failed", id, ["error": error.localizedDescription])
        case .loadingStarted(let id):
            return make("browser.loading.started", id)
        case .loadingFinished(let id, let duration):
            return make("browser.loading.finished", id, ["duration": String(duration)])
        case .historyChanged(let id, let count):
            return make("browser.history.changed", id, ["count": String(count)])
        case .cookiesChanged(let id, let count):
            return make("browser.cookies.changed", id, ["count": String(count)])
        case .storageChanged(let id, let state):
            return make("browser.storage.changed", id, ["state": state.rawValue])
        case .downloadStarted(let id, let downloadID):
            return make("browser.download.started", id, ["downloadId": downloadID.description])
        case .downloadFinished(let id, let downloadID):
            return make("browser.download.finished", id, ["downloadId": downloadID.description])
        case .downloadFailed(let id, let downloadID, let error):
            return make(
                "browser.download.failed",
                id,
                ["downloadId": downloadID.description, "error": error.localizedDescription]
            )
        case .webProcessTerminated(let id):
            return make("browser.process.terminated", id)
        }
    }

    private func make(
        _ name: String,
        _ browserId: BrowserID,
        _ attributes: [String: String] = [:]
    ) -> PlatformEvent {
        PlatformEvent(
            name: name,
            source: .browser,
            correlationID: browserId.description,
            attributes: attributes
        )
    }

    private func urlAttributes(_ url: URL?) -> [String: String] {
        guard let url else { return [:] }
        return ["url": url.absoluteString]
    }
}

final class BrowserEventEmitter {
    private let eventBus: EventBus

    init(eventBus: EventBus) {
        self.eventBus = eventBus
    }

    func emit(_ event: BrowserEvent) {
        eventBus.publish(event.platformEvent)
    }
}

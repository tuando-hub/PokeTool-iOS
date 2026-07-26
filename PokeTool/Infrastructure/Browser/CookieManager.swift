import Foundation
import WebKit

struct BrowserCookie: Codable, Hashable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
}

enum CookieSyncDirection {
    case webKitToShared
    case sharedToWebKit
}

@MainActor
final class CookieManager: NSObject {
    private let browserId: BrowserID
    private let cookieStore: WKHTTPCookieStore
    private let eventEmitter: BrowserEventEmitter
    private let logger: Logging

    init(
        browserId: BrowserID,
        cookieStore: WKHTTPCookieStore,
        eventEmitter: BrowserEventEmitter,
        logger: Logging
    ) {
        self.browserId = browserId
        self.cookieStore = cookieStore
        self.eventEmitter = eventEmitter
        self.logger = logger
        super.init()
        cookieStore.add(self)
    }

    func exportCookies() async -> [BrowserCookie] {
        let cookies = await allCookies()
        return cookies.map {
            BrowserCookie(
                name: $0.name,
                value: $0.value,
                domain: $0.domain,
                path: $0.path,
                expiresDate: $0.expiresDate,
                isSecure: $0.isSecure,
                isHTTPOnly: $0.isHTTPOnly
            )
        }
    }

    func importCookies(_ cookies: [BrowserCookie]) async throws {
        for cookie in cookies {
            guard let nativeCookie = makeNativeCookie(cookie) else {
                throw BrowserError.cookieOperationFailed("Invalid cookie \(cookie.name)")
            }
            await setCookie(nativeCookie)
        }
        notifyChanged(count: cookies.count)
    }

    func clear() async {
        let cookies = await allCookies()
        for cookie in cookies {
            await deleteCookie(cookie)
        }
        notifyChanged(count: 0)
    }

    func sync(_ direction: CookieSyncDirection) async {
        switch direction {
        case .webKitToShared:
            let cookies = await allCookies()
            cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
            notifyChanged(count: cookies.count)
        case .sharedToWebKit:
            let cookies = HTTPCookieStorage.shared.cookies ?? []
            for cookie in cookies {
                await setCookie(cookie)
            }
            notifyChanged(count: cookies.count)
        }
    }

    func stopObserving() {
        cookieStore.remove(self)
    }

    private func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { continuation.resume(returning: $0) }
        }
    }

    private func setCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            cookieStore.setCookie(cookie) { continuation.resume() }
        }
    }

    private func deleteCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            cookieStore.delete(cookie) { continuation.resume() }
        }
    }

    private func makeNativeCookie(_ cookie: BrowserCookie) -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: cookie.name,
            .value: cookie.value,
            .domain: cookie.domain,
            .path: cookie.path
        ]
        if let expiresDate = cookie.expiresDate {
            properties[.expires] = expiresDate
        }
        if cookie.isSecure {
            properties[.secure] = "TRUE"
        }
        if cookie.isHTTPOnly {
            properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
        }
        return HTTPCookie(properties: properties)
    }

    private func notifyChanged(count: Int) {
        logger.log(
            .debug,
            category: .browser,
            message: "Cookie store changed",
            metadata: ["browserId": browserId.description, "count": String(count)]
        )
        eventEmitter.emit(.cookiesChanged(browserId, count))
    }
}

extension CookieManager: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let cookies = await self.allCookies()
            self.notifyChanged(count: cookies.count)
        }
    }
}

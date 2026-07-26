import Foundation
import UIKit
import WebKit

protocol ScreenshotDestinationPolicy {
    func destination(format: BrowserScreenshotResult.Format) throws -> URL
}

final class ControlledScreenshotDestinationPolicy: ScreenshotDestinationPolicy {
    private let directory: URL
    init(fileManager: FileManager = .default) {
        directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeTool/Screenshots", isDirectory: true)
    }
    func destination(format: BrowserScreenshotResult.Format) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(format.rawValue == "png" ? "png" : "jpg")
    }
}

@MainActor
final class BrowserOperationCoordinator {
    private let eventEmitter: BrowserEventEmitter
    private let metrics: BrowserMetricsCollector
    private var invalidatedSessions: Set<BrowserID> = []

    init(eventEmitter: BrowserEventEmitter, metrics: BrowserMetricsCollector) {
        self.eventEmitter = eventEmitter
        self.metrics = metrics
    }

    func run<T>(
        browserId: BrowserID,
        name: String,
        timeout: TimeInterval,
        operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        guard timeout > 0 else { throw BrowserError.timeout(operation: name) }
        invalidatedSessions.remove(browserId)
        let id = BrowserOperationID()
        let start = Date()
        eventEmitter.emit(.operationStarted(browserId, id, name))
        metrics.operationStarted()
        do {
            let result = try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { @MainActor in try await operation() }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw BrowserError.timeout(operation: name)
                }
                guard let result = try await group.next() else { throw BrowserError.unknown(name) }
                group.cancelAll()
                return result
            }
            guard !invalidatedSessions.contains(browserId) else {
                throw BrowserError.cancelled(operation: name)
            }
            let duration = Date().timeIntervalSince(start)
            metrics.operationFinished(duration: duration, succeeded: true)
            eventEmitter.emit(.operationCompleted(browserId, id, name, duration))
            return result
        } catch is CancellationError {
            metrics.operationCancelled()
            eventEmitter.emit(.operationCancelled(browserId, id, name))
            throw BrowserError.cancelled(operation: name)
        } catch let error as BrowserError {
            metrics.operationFinished(duration: Date().timeIntervalSince(start), succeeded: false)
            if case .timeout = error { eventEmitter.emit(.operationTimedOut(browserId, id, name)) }
            else { eventEmitter.emit(.operationFailed(browserId, id, name, error)) }
            throw error
        } catch {
            throw BrowserError.unknown(error.localizedDescription)
        }
    }

    func cancelAll(for browserId: BrowserID) {
        invalidatedSessions.insert(browserId)
    }
}

@MainActor
final class BrowserNavigationOperations {
    func load(_ request: BrowserRequest, in session: BrowserSession) throws {
        session.webView.load(try request.validatedURLRequest())
    }
    func reload(_ session: BrowserSession, fromOrigin: Bool) {
        fromOrigin ? session.webView.reloadFromOrigin() : session.webView.reload()
    }
    func stop(_ session: BrowserSession) { session.webView.stopLoading() }
    func back(_ session: BrowserSession) { session.webView.goBack() }
    func forward(_ session: BrowserSession) { session.webView.goForward() }
}

@MainActor
final class BrowserJavaScriptOperations {
    func evaluate(_ source: String, in session: BrowserSession) async throws -> BrowserValue {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BrowserError.javaScriptExecutionFailed("Empty source")
        }
        do { return try BrowserValue(any: try await session.webView.evaluateJavaScript(source)) }
        catch let error as BrowserError { throw error }
        catch { throw BrowserError.javaScriptExecutionFailed(error.localizedDescription) }
    }

    func call(functionBody: String, arguments: [String: Any], in session: BrowserSession) async throws -> BrowserValue {
        do {
            let value = try await session.webView.callAsyncJavaScript(
                functionBody,
                arguments: arguments,
                in: nil,
                contentWorld: .page
            )
            return try BrowserValue(any: value)
        } catch let error as BrowserError { throw error }
        catch { throw BrowserError.javaScriptExecutionFailed(error.localizedDescription) }
    }
}

@MainActor
final class BrowserDOMOperations {
    private let javaScript: BrowserJavaScriptOperations
    init(javaScript: BrowserJavaScriptOperations) { self.javaScript = javaScript }

    func query(selector: String, property: String, in session: BrowserSession) async throws -> BrowserValue {
        try await javaScript.call(
            functionBody: """
            let element;
            try { element = document.querySelector(selector); } catch (_) { return {error:"selector"}; }
            if (!element) return {error:"notFound"};
            if (property === "visibility") {
              const r=element.getBoundingClientRect(), s=getComputedStyle(element);
              return {visible:r.width>0&&r.height>0&&s.visibility!=="hidden"&&s.display!=="none"&&Number(s.opacity)>0,
                      width:r.width,height:r.height,opacity:Number(s.opacity)};
            }
            if (property === "enabled") return !element.disabled;
            if (property === "tagName") return element.tagName;
            if (property === "value") return element.value ?? null;
            if (property === "checked") return Boolean(element.checked);
            return element[property] ?? null;
            """,
            arguments: ["selector": selector, "property": property],
            in: session
        )
    }

    func exists(selector: String, in session: BrowserSession) async throws -> Bool {
        let value = try await javaScript.call(
            functionBody: "try { return document.querySelector(selector) !== null; } catch (_) { return null; }",
            arguments: ["selector": selector],
            in: session
        )
        guard case .bool(let result) = value else { throw BrowserError.selectorSyntaxError(selector) }
        return result
    }

    func count(selector: String, in session: BrowserSession) async throws -> Int {
        let value = try await javaScript.call(
            functionBody: "try { return document.querySelectorAll(selector).length; } catch (_) { return null; }",
            arguments: ["selector": selector],
            in: session
        )
        guard case .integer(let result) = value else { throw BrowserError.selectorSyntaxError(selector) }
        return Int(result)
    }
}

enum BrowserElementAction: Sendable {
    case click, focus, blur, clear, submit, scrollIntoView
    case setValue(String), type(String), setChecked(Bool), selectValue(String), selectIndex(Int)
    case dispatch(String)
}

@MainActor
final class BrowserElementOperations {
    private let javaScript: BrowserJavaScriptOperations
    init(javaScript: BrowserJavaScriptOperations) { self.javaScript = javaScript }

    func perform(_ action: BrowserElementAction, selector: String, in session: BrowserSession) async throws {
        let payload: [String: Any]
        switch action {
        case .click: payload = ["action": "click"]
        case .focus: payload = ["action": "focus"]
        case .blur: payload = ["action": "blur"]
        case .clear: payload = ["action": "value", "value": ""]
        case .submit: payload = ["action": "submit"]
        case .scrollIntoView: payload = ["action": "scroll"]
        case .setValue(let value): payload = ["action": "value", "value": value]
        case .type(let value): payload = ["action": "type", "value": value]
        case .setChecked(let value): payload = ["action": "checked", "value": value]
        case .selectValue(let value): payload = ["action": "selectValue", "value": value]
        case .selectIndex(let value): payload = ["action": "selectIndex", "value": value]
        case .dispatch(let value): payload = ["action": "dispatch", "value": value]
        }
        let result = try await javaScript.call(
            functionBody: """
            let e; try { e=document.querySelector(selector); } catch(_){ return "selector"; }
            if(!e) return "notFound";
            const fire=n=>e.dispatchEvent(new Event(n,{bubbles:true}));
            switch(action){
              case "click": e.click(); break; case "focus": e.focus(); break; case "blur": e.blur(); break;
              case "scroll": e.scrollIntoView({block:"center"}); break;
              case "submit": (e.form||e).requestSubmit?.(); break;
              case "checked": e.checked=value; fire("input"); fire("change"); break;
              case "selectValue": e.value=value; fire("input"); fire("change"); break;
              case "selectIndex": e.selectedIndex=value; fire("input"); fire("change"); break;
              case "dispatch": if(!["focus","input","change","blur","click"].includes(value)) return "unsupported"; fire(value); break;
              case "type": e.focus(); e.value=(e.value||"")+value; fire("input"); break;
              case "value":
                const p=Object.getPrototypeOf(e), d=Object.getOwnPropertyDescriptor(p,"value");
                d?.set ? d.set.call(e,value) : e.value=value; fire("input"); fire("change"); break;
            }
            return "ok";
            """,
            arguments: ["selector": selector].merging(payload) { _, new in new },
            in: session
        )
        guard result == .string("ok") else {
            if result == .string("selector") { throw BrowserError.selectorSyntaxError(selector) }
            if result == .string("notFound") { throw BrowserError.elementNotFound(selector) }
            throw BrowserError.unsupportedOperation("element action")
        }
    }
}

@MainActor
final class BrowserCaptureOperations {
    private let destinations: ScreenshotDestinationPolicy
    init(destinations: ScreenshotDestinationPolicy) { self.destinations = destinations }

    func capture(
        session: BrowserSession,
        format: BrowserScreenshotResult.Format,
        quality: Double,
        fullContent: Bool
    ) async throws -> BrowserScreenshotResult {
        let configuration = WKSnapshotConfiguration()
        if fullContent { configuration.rect = CGRect(origin: .zero, size: session.webView.scrollView.contentSize) }
        let image = try await session.webView.takeSnapshot(configuration: configuration)
        let data: Data?
        switch format {
        case .png: data = image.pngData()
        case .jpeg: data = image.jpegData(compressionQuality: min(max(quality, 0), 1))
        }
        guard let data else { throw BrowserError.serializationFailed("Screenshot encoding failed") }
        let url = try destinations.destination(format: format)
        try data.write(to: url, options: [.atomic, .withoutOverwriting])
        return BrowserScreenshotResult(
            browserId: session.browserId, fileURL: url, format: format,
            width: Int(image.size.width * image.scale), height: Int(image.size.height * image.scale),
            timestamp: Date()
        )
    }
}

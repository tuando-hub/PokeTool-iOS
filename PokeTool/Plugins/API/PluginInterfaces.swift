import Foundation

struct PluginDescriptor: Hashable {
    let identifier: String
    let name: String
    let version: String
}

protocol PluginServiceResolving: AnyObject {
    func resolve<Service>(_ type: Service.Type) -> Service?
}

protocol PluginBridgeAccessing: AnyObject {
    var bridgeIdentifier: String { get }
}

struct PluginContext {
    let services: PluginServiceResolving
    let bridge: PluginBridgeAccessing
    let eventBus: EventBus
    let logger: Logging
}

protocol PokeToolPlugin: AnyObject {
    var descriptor: PluginDescriptor { get }
    func activate(context: PluginContext) throws
    func deactivate()
}


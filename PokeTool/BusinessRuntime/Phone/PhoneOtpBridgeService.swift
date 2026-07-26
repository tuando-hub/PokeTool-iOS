import Foundation

@MainActor final class PhoneOtpBridgeService: BaseInfrastructureService {
    private let configuration: PhoneGatewayConfiguration
    private var provider: RemotePhoneOtpProvider?
    init(configuration: PhoneGatewayConfiguration) { self.configuration=configuration; super.init(namespace:"PhoneOtp") }
    override var capabilities: [String: Any] { ["gateway":true,"providerNeutral":true,"emailOtpSeparate":true] }
    private func active() throws -> RemotePhoneOtpProvider { if let provider { return provider }; let p=try configuration.makeProvider();provider=p;return p }
    override func perform(method: String, arguments: [Any]) async throws -> Any { try checkRunning(method); guard let a=arguments.first as? [String:Any] else { throw failure("PHONEOTP_INVALID_REQUEST","Invalid arguments.",method) }; do { let p=try active(); switch method { case "health": return ["ok":try await p.health()]; case "createOrder": guard let service=a["service"] as? String,let country=a["country"] as? String,let requestId=a["requestId"] as? String,!service.isEmpty,!country.isEmpty,!requestId.isEmpty else {throw failure("PHONEOTP_INVALID_REQUEST","Missing order fields.",method)}; return try await encode(p.createOrder(PhoneGatewayOrderRequest(service:service,country:country,requestId:requestId))); case "getOrder": return try await encode(p.status(try id(a),otp:false)); case "waitForPhone": return try await encode(p.status(try id(a),otp:false)); case "waitForOtp": return try await encode(p.status(try id(a),otp:true)); case "cancel": return try await encode(p.cancel(try id(a))); case "release": return try await encode(p.release(try id(a))); default: throw failure("PHONEOTP_UNSUPPORTED_OPERATION","Unsupported operation.",method) } } catch let e as InfrastructureBridgeError { throw e } catch { throw failure("PHONEOTP_PROVIDER_ERROR","Phone gateway operation failed.",method) } }
    private func id(_ a:[String:Any]) throws -> String { guard let id=a["orderId"] as? String,!id.isEmpty else {throw failure("PHONEOTP_INVALID_REQUEST","Missing gateway order ID.","id")};return id }
    private func encode(_ order:PhoneGatewayOrder) -> [String:Any] { ["ok":true,"orderId":order.id,"status":order.status,"phone":order.phone as Any,"otp":order.otp as Any,"expiresAt":order.expiresAt as Any] }
}

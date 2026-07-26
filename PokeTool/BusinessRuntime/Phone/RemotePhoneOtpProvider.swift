import Foundation
enum RemotePhoneOtpError: Error { case invalidBaseURL, unauthorized, malformedResponse, server(code: String) }
struct PhoneGatewayOrderRequest: Codable { let service: String; let country: String; let requestId: String }
struct PhoneGatewayOrder: Codable { let id: String; let status: String; let phone: String?; let otp: String?; let expiresAt: String? }
struct PhoneGatewayEnvelope: Codable { let ok: Bool; let order: PhoneGatewayOrder?; let error: GatewayError? }
struct GatewayError: Codable { let code: String; let message: String }
final class RemotePhoneOtpProvider {
 private let baseURL: URL; private let apiKey: String; private let session: URLSession
 init(baseURL: String, apiKey: String, session: URLSession = .shared) throws { guard let u=URL(string: baseURL),u.scheme=="https",u.host != nil else {throw RemotePhoneOtpError.invalidBaseURL}; self.baseURL=u;self.apiKey=apiKey;self.session=session }
 func health() async throws -> Bool { let (_,r)=try await request(path:"/health",method:"GET",body:Optional<PhoneGatewayOrderRequest>.none); return (200..<300).contains(r.statusCode) }
 func createOrder(_ body: PhoneGatewayOrderRequest) async throws -> PhoneGatewayOrder { try await decode(path:"/v1/phone/orders",method:"POST",body:body) }
 func status(_ id:String,otp:Bool=false) async throws -> PhoneGatewayOrder { try await decode(path:"/v1/phone/orders/\(id)\(otp ? "/otp" : "")",method:"GET",body:Optional<PhoneGatewayOrderRequest>.none) }
 func cancel(_ id:String) async throws -> PhoneGatewayOrder { try await decode(path:"/v1/phone/orders/\(id)/cancel",method:"POST",body:Optional<PhoneGatewayOrderRequest>.none) }
 func release(_ id:String) async throws -> PhoneGatewayOrder { try await decode(path:"/v1/phone/orders/\(id)/release",method:"POST",body:Optional<PhoneGatewayOrderRequest>.none) }
 private func decode<T:Encodable>(path:String,method:String,body:T?) async throws -> PhoneGatewayOrder { let (d,_)=try await request(path:path,method:method,body:body); guard let e=try? JSONDecoder().decode(PhoneGatewayEnvelope.self,from:d),e.ok,let o=e.order else { throw RemotePhoneOtpError.malformedResponse }; if let x=e.error { throw RemotePhoneOtpError.server(code:x.code) }; return o }
 private func request<T:Encodable>(path:String,method:String,body:T?) async throws -> (Data,HTTPURLResponse) { try Task.checkCancellation(); guard let u=URL(string:path,relativeTo:baseURL) else {throw RemotePhoneOtpError.invalidBaseURL}; var r=URLRequest(url:u);r.httpMethod=method;r.timeoutInterval=20;r.setValue("Bearer \(apiKey)",forHTTPHeaderField:"Authorization");if let body {r.httpBody=try JSONEncoder().encode(body);r.setValue("application/json",forHTTPHeaderField:"Content-Type")};let(d,res)=try await session.data(for:r);guard let h=res as? HTTPURLResponse else {throw RemotePhoneOtpError.malformedResponse};if h.statusCode==401 {throw RemotePhoneOtpError.unauthorized};guard (200..<300).contains(h.statusCode) else {throw RemotePhoneOtpError.server(code:"HTTP_\(h.statusCode)")};return(d,h) }
}

import Foundation

protocol BrowserAutomating: AnyObject {
    func load(url: URL, completion: @escaping (Result<Void, Error>) -> Void)
    func evaluate(script: String, completion: @escaping (Result<Any?, Error>) -> Void)
    func clear(completion: @escaping (Result<Void, Error>) -> Void)
    func stop()
}


import Combine
import Foundation

final class NativeEventBus: EventBus {
    private let subject = PassthroughSubject<PlatformEvent, Never>()
    private let deliveryQueue = DispatchQueue(label: "com.dodinh.poketool.eventbus")

    var events: AnyPublisher<PlatformEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func publish(_ event: PlatformEvent) {
        deliveryQueue.async { [subject = self.subject] in
            subject.send(event)
        }
    }
}

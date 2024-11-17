//
//  EventViewModel.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import RxSwift
import RxCocoa
import VATextureKitRx

struct BecomeVisibleEvent: Event {}

protocol Event {}

class EventViewModel: ViewModel {
    let bag = DisposeBag()
    let eventRelay = PublishRelay<any Event>()
    var isLoadingObs: Observable<Bool> { isLoadingRelay.asObservable() }
    var isNotLoading: Bool { !isLoadingRelay.value }
    weak var controller: UIViewController?
    var isLoadingRelay = BehaviorRelay(value: false)

    let scheduler: any SchedulerType

    init(scheduler: any SchedulerType = MainScheduler.asyncInstance) {
        self.scheduler = scheduler

        super.init()

        bind()
    }

    func run(_ event: any Event) {
        #if DEBUG || targetEnvironment(simulator)
        debugPrint("⚠️ [Event not handled] \(event)")
        #endif
    }

    func perform(_ event: any Event) {
        eventRelay.accept(event)
    }

    private func bind() {
        eventRelay
            .observe(on: scheduler)
            .subscribe(onNext: self ?>> { $0.run(_:) })
            .disposed(by: bag)
    }
}

class ViewModel: NSObject, Responder {

    // MARK: - Responder

    weak var nextEventResponder: (any Responder)?

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }
}

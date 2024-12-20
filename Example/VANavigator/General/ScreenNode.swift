//
//  ScreenNode.swift
//  VANavigator_Example
//
//  Created by VAndrJ on 03.12.2023.
//  Copyright © 2023 Volodymyr Andriienko. All rights reserved.
//

import RxSwift
import RxCocoa
import VATextureKitRx
import RxKeyboard

class ScreenNode<ViewModel: EventViewModel>: VASafeAreaDisplayNode, ControllerNode, Responder, @unchecked Sendable {
    let bag = DisposeBag()
    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel

        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        bind()
    }

    @MainActor
    private func bind() {
        bindView()
        bindViewModel()
    }

    @MainActor
    func bindView() {}

    @MainActor
    func bindViewModel() {}

    @MainActor
    func configure() {}

    @MainActor
    func bindKeyboardInset(scrollView: UIScrollView, tabBarController: UITabBarController? = nil) {
        let initialBottomInset = scrollView.contentInset.bottom
        let initialIndicatorBottomInset = scrollView.verticalScrollIndicatorInsets.bottom
        Observable
            .combineLatest(
                RxKeyboard.instance.visibleHeight
                    .asObservable()
                    .distinctUntilChanged(),
                rx.observe(UIEdgeInsets.self, #keyPath(ASDisplayNode.safeAreaInsets))
                    .compactMap(\.?.bottom)
                    .distinctUntilChanged(),
                Observable
                    .combineLatest(
                        tabBarController?.tabBar.rx.observe(CGRect.self, #keyPath(UITabBar.bounds))
                            .compactMap(\.?.height)
                            .distinctUntilChanged() ?? .just(0),
                        tabBarController?.view.rx.observe(UIEdgeInsets.self, #keyPath(UIView.safeAreaInsets))
                            .compactMap(\.?.bottom)
                            .distinctUntilChanged() ?? .just(0)
                    )
                    .map { $0 + $1 }
            )
            .map { keyboardHeight, safeAreaBottom, tabBarHeght in
                let possibleBottomInset = keyboardHeight - max(safeAreaBottom, tabBarHeght)

                return (max(possibleBottomInset, initialBottomInset), max(possibleBottomInset, initialIndicatorBottomInset))
            }
            .subscribe(onNext: { [weak scrollView] bottomInset, indicatorBottomInset in
                scrollView?.contentInset.bottom = bottomInset
                scrollView?.verticalScrollIndicatorInsets.bottom = indicatorBottomInset
            })
            .disposed(by: bag)
    }

    // MARK: - ControllerNode

    func viewDidLoad(in controller: UIViewController) {
        viewModel.controller = controller
    }

    func viewDidAppear(in controller: UIViewController, animated: Bool) {}

    func viewWillAppear(in controller: UIViewController, animated: Bool) {}

    func viewWillDisappear(in controller: UIViewController, animated: Bool) {}

    func viewDidDisappear(in controller: UIViewController, animated: Bool) {}

    // MARK: - Responder

    var nextEventResponder: (any Responder)? {
        get { viewModel }
        set { viewModel.nextEventResponder = newValue }
    }

    func handle(event: any ResponderEvent) async -> Bool {
        logResponder(from: self, event: event)

        return await nextEventResponder?.handle(event: event) ?? false
    }

    deinit {
        #if DEBUG || targetEnvironment(simulator)
        print(#function, String(describing: Self.self))
        #endif
    }
}

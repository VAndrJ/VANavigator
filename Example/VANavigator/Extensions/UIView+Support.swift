//
//  UIView+Support.swift
//  VANavigator
//
//  Created by Volodymyr Andriienko on 15.07.2026.
//  Copyright © 2026 Volodymyr Andriienko. All rights reserved.
//

import UIKit

extension UIView {
    func addAutolayoutSubview(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
    }

    func addAutolayoutSubviews(_ views: UIView...) {
        views.forEach { addAutolayoutSubview($0) }
    }

    func embedIntoScroll(_ views: any LayoutElement...) {
        let spacing: CGFloat = 16
        let scrollView = UIScrollView().apply {
            $0.alwaysBounceVertical = true
        }
        addAutolayoutSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            scrollView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
        ])
        let containerView = UIStackView().apply {
            $0.axis = .vertical
            $0.spacing = spacing
        }
        scrollView.addAutolayoutSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -spacing * 2),
        ])
        scrollView.contentInset = .init(all: spacing)
        views.forEach {
            if let view = $0 as? UIView {
                containerView.addArrangedSubview(view)
            }
            if let spacing = $0 as? Spacing {
                containerView.addArrangedSubview(spacing.child)
                containerView.setCustomSpacing(spacing.value, after: spacing.child)
            }
        }
    }
}

extension UIView: LayoutElement {}

struct Spacing: LayoutElement {
    let value: CGFloat
    let child: UIView
}

protocol LayoutElement {}

extension UITextField {
    var onEditingChanged: ((String?) -> Void)? {
        get { nil }
        set {
            addAction(
                UIAction { [weak self] _ in
                    newValue?(self?.text)
                },
                for: .editingChanged
            )
        }
    }
}

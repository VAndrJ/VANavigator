//
//  UIView+Support.swift
//  SimpleExample
//
//  Created by VAndrJ on 13.02.2024.
//

import UIKit

extension UIView {

    func addAutolayoutSubview(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
    }

    func addAutolayoutSubviews(_ views: UIView...) {
        views.forEach(addAutolayoutSubview(_:))
    }

    func embedIntoScroll(_ views: UIView...) {
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
            $0.spacing = 16
        }
        scrollView.addAutolayoutSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            containerView.leftAnchor.constraint(equalTo: scrollView.leftAnchor, constant: 16),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            containerView.rightAnchor.constraint(equalTo: scrollView.rightAnchor, constant: -16),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        views.forEach(containerView.addArrangedSubview(_:))
    }
}

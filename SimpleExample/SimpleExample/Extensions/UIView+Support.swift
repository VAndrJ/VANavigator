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
        views.forEach { addAutolayoutSubview($0) }
    }

    func embedIntoScroll(_ views: UIView...) {
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
        scrollView.contentInset = UIEdgeInsets(all: spacing)
        views.forEach { containerView.addArrangedSubview($0) }
    }
}

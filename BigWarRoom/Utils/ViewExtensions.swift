//
//  ViewExtensions.swift
//  BigWarRoom
//
//  Useful view modifiers and extensions
//

import SwiftUI

extension View {
    /// Conditionally applies a transformation to a view
    ///
    /// Example:
    /// ```swift
    /// Text("Hello")
    ///     .if(someCondition) { view in
    ///         view.bold()
    ///     }
    /// ```
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Conditionally applies one of two transformations to a view
    ///
    /// Example:
    /// ```swift
    /// Text("Hello")
    ///     .if(someCondition,
    ///         then: { $0.foregroundColor(.green) },
    ///         else: { $0.foregroundColor(.red) }
    ///     )
    /// ```
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        then trueTransform: (Self) -> TrueContent,
        else falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }
}
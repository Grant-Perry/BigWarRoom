//
//  View+Extensions.swift
//  BigWarRoom
//
//  🔥 DRY CONSOLIDATION: All View extensions in one place
//  Migrated from: View+Misc.swift, ViewExtensions.swift, AsyncTaskService.swift, etc.
//

import SwiftUI

// MARK: - Siri Animation

extension View {
    /// Apply Siri-style Dancing Gradient Animation with State Control
    /// Perfect for live updating views that need visual indication of real-time data
    func siriAnimate(
        isActive: Bool = true,
        intensity: Double = 0.6,
        speed: Double = 1.0,
        baseColors: [Color] = [.blue, .purple, .pink, .orange, .green]
    ) -> some View {
        self.modifier(
            SiriAnimationModifier(
                isActive: isActive,
                intensity: intensity,
                speed: speed,
                baseColors: baseColors
            )
        )
    }
}

// MARK: - Notification Badge

extension View {
    /// Apply iOS notification badge matching Apple's official specifications
    func notificationBadge(
        count: Int,
        xOffset: CGFloat = 4,
        yOffset: CGFloat = -8,
        badgeColor: Color = .gpRedPink
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            self
            
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .default))
                    .kerning(-0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, count >= 10 ? 6 : 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(badgeColor)
                    )
                    .frame(minWidth: 20, minHeight: 20)
                    .offset(x: xOffset, y: yOffset)
            }
        }
    }
}

// MARK: - Conditional Modifiers

extension View {
    /// Conditionally applies a transformation to a view
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

// MARK: - Async Task Execution

extension View {
    /// Execute async task when view appears
    func asyncOnAppear(
        id: String? = nil,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @MainActor () async throws -> Void
    ) -> some View {
        self.onAppear {
            AsyncTaskService.shared.run(id: id, priority: priority, operation)
        }
    }
    
    /// Execute debounced async task
    func asyncDebounced(
        id: String,
        delay: TimeInterval = 0.5,
        priority: TaskPriority = .userInitiated,
        _ operation: @escaping @MainActor () async throws -> Void
    ) -> some View {
        self.onChange(of: id) { _, _ in
            AsyncTaskService.shared.debounce(id: id, delay: delay, priority: priority, operation)
        }
    }
}

// MARK: - Keyboard Adaptive

extension View {
    /// Adapt to keyboard show/hide events
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    keyboardHeight = keyboardFrame.cgRectValue.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
            .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
    }
}

// MARK: - Win Probability Engine Access

extension View {
    /// Access win probability engine from any view
    var winProbabilityEngine: WinProbabilityEngine {
        WinProbabilityEngine.shared
    }
}

// MARK: - Image Styling (from PlayerCardComponents)

extension View {
    /// Apply image styling configuration
    func applyImageStyling(configuration: PlayerImageConfiguration) -> some View {
        self.modifier(ImageStylingModifier(configuration: configuration))
    }
}

struct ImageStylingModifier: ViewModifier {
    let configuration: PlayerImageConfiguration
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
    func body(content: Content) -> some View {
        switch configuration.borderStyle {
        case .none:
            content.clipShape(Circle())
            
        case .position(let position):
            content
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            colorService.positionColor(for: position).opacity(0.6),
                            lineWidth: 2
                        )
                )
                
        case .team(let team):
            content
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(team.primaryColor.opacity(0.6), lineWidth: 2)
                )
                
        case .custom(let color, let width):
            content
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: width)
                )
        }
    }
}
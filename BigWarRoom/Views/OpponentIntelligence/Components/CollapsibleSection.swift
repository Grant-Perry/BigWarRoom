//
//  CollapsibleSection.swift
//  BigWarRoom
//
//  Reusable collapsible section component for Intelligence Dashboard
//

import SwiftUI

/// Collapsible section with header and expandable content
struct CollapsibleSection<Content: View>: View {
    let title: String
    let notice: String?
    let count: Int
    @Binding var isExpanded: Bool
    let infoAction: (() -> Void)? // NEW: Optional info action
    @ViewBuilder let content: Content
    
    // Single unified init with all optional parameters
    init(
        title: String,
        notice: String? = nil,
        count: Int,
        isExpanded: Binding<Bool>,
        infoAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.notice = notice
        self.count = count
        self._isExpanded = isExpanded
        self.infoAction = infoAction
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 16)
                    
                    // Title
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Info button if provided
                    if let infoAction = infoAction {
                        Button(action: infoAction) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Count badge
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Notice section if provided
            if let notice = notice {
                Text(notice)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
            }
            
            // Content
            if isExpanded && count > 0 {
                VStack(spacing: 0) {
                    content
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.top, 2)
            }
        }
    }
}
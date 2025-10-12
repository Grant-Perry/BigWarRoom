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
    var notice: String? = ""
    let count: Int
    @Binding var isExpanded: Bool
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                    
                    if let notice = notice, !notice.isEmpty {
                        Text(notice)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("\(count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 8)
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle()) // Make entire area tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable content
            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}

// MARK: - Preview

#Preview("Collapsible Section") {
    VStack(spacing: 16) {
        CollapsibleSection(
            title: "Player Injury Alerts",
            count: 3,
            isExpanded: .constant(true)
        ) {
            VStack(spacing: 8) {
                Text("Josh Allen - BYE Week")
                Text("Cooper Kupp - Out")
                Text("Travis Kelce - Questionable")
            }
            .padding(.vertical, 8)
        }
        
        CollapsibleSection(
            title: "Threat Matrix",
            count: 5,
            isExpanded: .constant(false)
        ) {
            Text("Collapsed content")
        }
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
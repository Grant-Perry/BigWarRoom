//
//  CollapsibleRosterSectionView.swift
//  BigWarRoom
//
//  Reusable collapsible section component for roster views
//

import SwiftUI

/// Generic collapsible section component for roster display
struct CollapsibleRosterSectionView<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    let content: Content
    
    init(
        title: String,
        subtitle: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isExpanded = isExpanded
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .foregroundColor(.primary)
            
            // Collapsible Content
            if isExpanded {
                content
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
//
//  PlayoffLastPlayDetailModal.swift
//  BigWarRoom
//
//  Modal displaying full last play text
//

import SwiftUI

struct PlayoffLastPlayDetailModal: View {
    let lastPlayText: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Last Play")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(height: 36)
                .background(Color(.systemGray6))
                
                Text(lastPlayText)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 280)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 5)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}
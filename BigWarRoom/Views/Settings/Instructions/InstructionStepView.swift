//
//  InstructionStepView.swift
//  BigWarRoom
//
//  Reusable instruction step component
//

import SwiftUI

/// Reusable component for displaying numbered instruction steps
struct InstructionStepView: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number circle
            StepNumberCircle(number: number)
            
            // Step content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Components

/// Step number circle component
private struct StepNumberCircle: View {
    let number: String
    
    var body: some View {
        Text(number)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(.blue))
    }
}
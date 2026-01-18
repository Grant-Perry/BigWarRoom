//
//  DraftSelectionCard.swift
//  BigWarRoom
//
//  Card for selecting from available drafts
//
// MARK: -> Draft Selection Card

import SwiftUI

struct DraftSelectionCard: View {
    let draft: SleeperLeague
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var statusColor: Color {
        switch draft.status {
        case .drafting: return .green
        case .preDraft: return .orange
        case .inSeason: return .blue
        case .postSeason: return .purple
        case .complete: return .gray
        }
    }
    
    private var statusEmoji: String {
        switch draft.status {
        case .drafting: return "🔴"
        case .preDraft: return "⏰"
        case .inSeason: return "🏈"
        case .postSeason: return "🏆"
        case .complete: return "✅"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Status indicator
                VStack {
                    Text(statusEmoji)
                        .font(.title2)
                    
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
                
                // Draft info
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(draft.status.displayName)
                            .font(.caption)
                            .foregroundColor(statusColor)
                            .fontWeight(.medium)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(draft.totalRosters) teams")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(draft.season)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let draftID = draft.draftID {
                        Text("ID: \(String(draftID.suffix(12)))")
                            .font(.caption2)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("ACTIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
//
//  FantasyAnalysisView.swift
//  BigWarRoom
//
//  Fantasy analysis section using ViewModel data
//

import SwiftUI

/// Fantasy analysis section with tier information and draft recommendations
struct FantasyAnalysisView: View {
    let fantasyAnalysisData: FantasyAnalysisData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fantasy Analysis")
                .font(.headline)
            
            if let data = fantasyAnalysisData {
                analysisContent(data)
            } else {
                noAnalysisView
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func analysisContent(_ data: FantasyAnalysisData) -> some View {
        VStack(spacing: 12) {
            fantasyRow("Search Rank", "#\(data.searchRank)", data.tierColor)
            fantasyRow("Fantasy Tier", "Tier \(data.tier)", data.tierColor)
            
            Text(data.tierDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            // Position-specific analysis
            Text(data.positionAnalysis)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    
    private var noAnalysisView: some View {
        Text("No fantasy analysis available")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
    }
    
    private func fantasyRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}
//
//  MoveInstructionsView.swift
//  BigWarRoom
//
//  Step-by-step move instructions for Lineup RX
//

import SwiftUI

struct MoveInstructionsView: View {
    let result: LineupOptimizerService.OptimizationResult
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerButton
            
            if isExpanded {
                contentView
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    private var headerButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                SectionHeader(icon: "list.bullet.clipboard", title: "Step-by-Step Instructions", color: .gpBlue)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gpBlue)
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Here's exactly how to optimize your lineup:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ForEach(result.moveChains.indices, id: \.self) { index in
                MoveChainCard(chain: result.moveChains[index], chainNumber: index + 1)
            }
            
            if !result.changes.isEmpty {
                totalImprovementCard
            }
        }
    }
    
    private var totalImprovementCard: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text("TOTAL IMPROVEMENT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Text("+\(String(format: "%.1f", result.improvement)) pts")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.gpGreen)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gpGreen.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gpGreen.opacity(0.5), lineWidth: 2)
                    )
            )
            Spacer()
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
            )
    }
}

struct MoveChainCard: View {
    let chain: LineupOptimizerService.MoveChain
    let chainNumber: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chainHeader
            ForEach(chain.steps.indices, id: \.self) { stepIndex in
                CascadingMoveStepRow(
                    step: chain.steps[stepIndex],
                    stepNumber: stepIndex + 1,
                    isLastStep: stepIndex == chain.steps.count - 1
                )
            }
        }
        .padding()
        .background(chainCardBackground)
    }
    
    private var chainHeader: some View {
        HStack {
            Text("Move Chain \(chainNumber)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gpBlue)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.gpGreen)
                Text("+\(String(format: "%.1f", chain.netImprovement)) pts")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gpGreen)
            }
        }
    }
    
    private var chainCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
            )
    }
}

struct CascadingMoveStepRow: View {
    let step: LineupOptimizerService.MoveStep
    let stepNumber: Int
    let isLastStep: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            stepNumberView
            stepDetailsView
        }
        .padding(.vertical, 4)
    }
    
    private var stepNumberView: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(stepColor)
                    .frame(width: 32, height: 32)
                Text("\(stepNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            if !isLastStep {
                Rectangle()
                    .fill(Color.gpBlue.opacity(0.3))
                    .frame(width: 2, height: 30)
            }
        }
    }
    
    private var stepDetailsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            playerNameRow
            actionRow
            Text(step.reason)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
                .italic()
        }
    }
    
    private var playerNameRow: some View {
        HStack {
            Text(step.player.fullName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("(\(step.player.position), \(String(format: "%.1f", step.projection)) pts)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
        }
    }
    
    private var actionRow: some View {
        HStack(spacing: 6) {
            actionIcon
            actionText
        }
    }
    
    @ViewBuilder
    private var actionIcon: some View {
        if step.toSlot == "BENCH" {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.gpRedPink)
        } else if step.fromSlot == "BENCH" {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(.gpGreen)
        } else {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(.gpBlue)
        }
    }
    
    @ViewBuilder
    private var actionText: some View {
        if step.toSlot == "BENCH" {
            Text("Bench from \(step.fromSlot)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gpRedPink)
        } else if step.fromSlot == "BENCH" {
            Text("Start in \(step.toSlot)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gpGreen)
        } else {
            Text("\(step.fromSlot) → \(step.toSlot)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gpBlue)
        }
    }
    
    private var stepColor: Color {
        if step.toSlot == "BENCH" {
            return .gpRedPink
        } else if step.fromSlot == "BENCH" {
            return .gpGreen
        } else {
            return .gpBlue
        }
    }
}
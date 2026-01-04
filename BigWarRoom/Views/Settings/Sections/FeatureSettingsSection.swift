//
//  FeatureSettingsSection.swift
//  BigWarRoom
//
//  Feature-specific settings: Lineup RX, Win Probability, Odds
//

import SwiftUI

struct FeatureSettingsSection: View {
   @Binding var isExpanded: Bool
   @Binding var lineupThreshold: Double
   @Binding var winProbabilitySD: Double
   @Binding var preferredSportsbook: String
   
   let onThresholdReset: () -> Void
   let onThresholdChange: (Double) -> Void
   
   private var winProbabilityDescription: String {
      let sd = winProbabilitySD
      if sd <= 20 {
         return "Aggressive (big leads = high %)"
      } else if sd <= 35 {
         return "Moderate"
      } else if sd <= 50 {
         return "ESPN-like (balanced)"
      } else {
         return "Conservative (stays near 50%)"
      }
   }
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("Features")
                  .font(.headline)
                  .foregroundColor(.white)
               
               Spacer()
               
               Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                  .foregroundColor(.secondary)
                  .font(.system(size: 14, weight: .semibold))
            }
         }
         .buttonStyle(.plain)
         
         if isExpanded {
            // Lineup RX Threshold
            VStack(alignment: .leading, spacing: 12) {
               HStack {
                  Image(systemName: "cross.case.fill")
                     .foregroundColor(.gpGreen)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Lineup RX Threshold")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Only suggest moves with \(Int(lineupThreshold))%+ improvement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Button(action: onThresholdReset) {
                     Text("Reset")
                        .font(.caption)
                        .foregroundColor(.gpBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gpBlue.opacity(0.1))
                        .cornerRadius(6)
                  }
                  .opacity(lineupThreshold == 10.0 ? 0.5 : 1.0)
                  .disabled(lineupThreshold == 10.0)
               }
               
               VStack(spacing: 8) {
                  Slider(value: $lineupThreshold, in: 10...100, step: 5)
                     .tint(.gpGreen)
                     .onChange(of: lineupThreshold) { _, newValue in
                        onThresholdChange(newValue)
                     }
                  
                  HStack {
                     Text("10%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                     Spacer()
                     Text("50%")
                        .font(.caption2)
                        .foregroundColor(.gpGreen)
                     Spacer()
                     Text("100%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                  }
               }
               .padding(.horizontal, 28)
            }
            .padding(.vertical, 8)
            
            // Win Probability Model
            VStack(alignment: .leading, spacing: 12) {
               HStack {
                  Image(systemName: "chart.bar.fill")
                     .foregroundColor(.purple)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Win Probability Model")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("SD: \(Int(winProbabilitySD)) – \(winProbabilityDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Button(action: {
                     winProbabilitySD = 40.0
                  }) {
                     Text("Reset")
                        .font(.caption)
                        .foregroundColor(.gpBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gpBlue.opacity(0.1))
                        .cornerRadius(6)
                  }
                  .opacity(winProbabilitySD == 40.0 ? 0.5 : 1.0)
                  .disabled(winProbabilitySD == 40.0)
               }
               
               VStack(spacing: 8) {
                  HStack {
                     Slider(value: $winProbabilitySD, in: 10...80, step: 1)
                        .tint(.purple)
                     
                     Text("\(Int(winProbabilitySD))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 28)
                        .background(
                           RoundedRectangle(cornerRadius: 6)
                              .fill(Color.purple)
                        )
                  }
                  
                  HStack {
                     Text("10")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                     Text("Aggressive")
                        .font(.caption2)
                        .foregroundColor(.gpGreen)
                     Spacer()
                     Text("40")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                     Spacer()
                     Text("Conservative")
                        .font(.caption2)
                        .foregroundColor(.orange)
                     Text("80")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                  }
               }
               .padding(.horizontal, 28)
            }
            .padding(.vertical, 8)
            
            // Sportsbook Preference
            VStack(alignment: .leading, spacing: 12) {
               HStack {
                  Image(systemName: "dollarsign.circle.fill")
                     .foregroundColor(.green)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Odds Source")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Which sportsbook lines to display on Schedule")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
               }
               
               LazyVGrid(columns: [
                  GridItem(.flexible()),
                  GridItem(.flexible()),
                  GridItem(.flexible()),
                  GridItem(.flexible())
               ], spacing: 8) {
                  ForEach(Sportsbook.allCases) { book in
                     Button {
                        preferredSportsbook = book.rawValue
                     } label: {
                        VStack(spacing: 4) {
                           Text(book.abbreviation)
                              .font(.system(size: 12, weight: .black, design: .rounded))
                              .foregroundColor(book.textColor)
                              .frame(width: 40, height: 24)
                              .background(
                                 RoundedRectangle(cornerRadius: 4)
                                    .fill(book.primaryColor)
                              )
                              .overlay(
                                 RoundedRectangle(cornerRadius: 4)
                                    .stroke(preferredSportsbook == book.rawValue ? Color.white : Color.clear, lineWidth: 2)
                              )
                           
                           Text(book == .bestLine ? "Best" : book.abbreviation)
                              .font(.system(size: 9, weight: .medium))
                              .foregroundColor(preferredSportsbook == book.rawValue ? .white : .secondary)
                        }
                     }
                     .buttonStyle(.plain)
                  }
               }
               .padding(.leading, 32)
            }
            .padding(.vertical, 4)
         }
      } footer: {
         if isExpanded {
            Text("Configure feature-specific settings and thresholds.")
         }
      }
   }
}
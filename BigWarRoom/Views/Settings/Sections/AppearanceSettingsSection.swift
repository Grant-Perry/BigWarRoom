//
//  AppearanceSettingsSection.swift
//  BigWarRoom
//
//  UI/UX settings: card designs, layouts, caching
//

import SwiftUI

struct AppearanceSettingsSection: View {
   @Binding var isExpanded: Bool
   @Binding var useRedesignedCards: Bool
   @Binding var useBarLayout: Bool
   @Binding var matchupCacheEnabled: Bool
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("Appearance")
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
            // Modern Player Card Design
            HStack {
               Image(systemName: "sparkles")
                  .foregroundColor(.gpYellow)
                  .frame(width: 24)
               
               VStack(alignment: .leading, spacing: 2) {
                  Text("Modern Player Card Design")
                     .font(.subheadline)
                     .fontWeight(.medium)
                  
                  Text("Thin, horizontal layout inspired by ESPN/Sleeper")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               Toggle("", isOn: $useRedesignedCards)
                  .labelsHidden()
            }
            
            // Mission Control Bar Layout
            HStack {
               Image(systemName: "rectangle.stack.fill")
                  .foregroundColor(.blue)
                  .frame(width: 24)
               
               VStack(alignment: .leading, spacing: 2) {
                  Text("Mission Control Bar Layout")
                     .font(.subheadline)
                     .fontWeight(.medium)
                  
                  Text("Modern horizontal bars for matchups")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               Toggle("", isOn: $useBarLayout)
                  .labelsHidden()
            }
            
            // Matchup Caching
            VStack(alignment: .leading, spacing: 12) {
               HStack {
                  Image(systemName: "bolt.fill")
                     .foregroundColor(.gpGreen)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Enable Matchup Caching")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Cache matchup structure per week for faster loading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Toggle("", isOn: $matchupCacheEnabled)
                     .labelsHidden()
                     .onChange(of: matchupCacheEnabled) { _, newValue in
                        MatchupCacheManager.shared.setCacheEnabled(newValue)
                     }
               }
               
               if matchupCacheEnabled {
                  VStack(alignment: .leading, spacing: 8) {
                     HStack {
                        Image(systemName: "info.circle.fill")
                           .foregroundColor(.blue.opacity(0.7))
                           .font(.system(size: 12))
                        
                        if let cacheInfo = MatchupCacheManager.shared.getCacheInfo() {
                           Text(cacheInfo)
                              .font(.caption2)
                              .foregroundColor(.secondary)
                        } else {
                           Text("No cached data yet")
                              .font(.caption2)
                              .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(MatchupCacheManager.shared.getCacheSizeString())
                           .font(.caption2)
                           .foregroundColor(.secondary)
                     }
                     
                     Button(role: .destructive) {
                        MatchupCacheManager.shared.clearAllCache()
                     } label: {
                        HStack {
                           Image(systemName: "trash.fill")
                              .font(.system(size: 12))
                           Text("Clear Matchup Cache")
                              .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                     }
                  }
                  .padding(.leading, 32)
                  .padding(.top, 4)
               }
            }
            .padding(.vertical, 4)
         }
      } footer: {
         if isExpanded {
            Text("Customize the look and feel of the app.")
         }
      }
   }
}
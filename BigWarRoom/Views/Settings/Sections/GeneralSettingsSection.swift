//
//  GeneralSettingsSection.swift
//  BigWarRoom
//
//  General app behavior settings: auto-refresh, keep active, eliminated leagues
//

import SwiftUI

struct GeneralSettingsSection: View {
   @Binding var isExpanded: Bool
   @Binding var autoRefreshEnabled: Bool
   @Binding var matchupRefresh: Int
   @Binding var keepAppActive: Bool
   @Binding var showEliminatedChoppedLeagues: Bool
   @Binding var showEliminatedPlayoffLeagues: Bool
   
   let onAutoRefreshChange: (Bool) -> Void
   let onKeepActiveChange: (Bool) -> Void
   let onChoppedChange: (Bool) -> Void
   let onPlayoffChange: (Bool) -> Void
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("General")
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
            // Auto-Refresh Toggle
            HStack {
               Image(systemName: "arrow.clockwise")
                  .foregroundColor(.blue)
                  .frame(width: 24)
               
               VStack(alignment: .leading, spacing: 2) {
                  Text("Auto-Refresh")
                     .font(.subheadline)
                     .fontWeight(.medium)
                  
                  Text("Refresh interval: \(matchupRefresh)s")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               Toggle("", isOn: $autoRefreshEnabled)
                  .labelsHidden()
                  .onChange(of: autoRefreshEnabled) { _, newValue in
                     onAutoRefreshChange(newValue)
                  }
            }
            
            // Live Refresh Interval Slider
            VStack(alignment: .leading, spacing: 8) {
               HStack {
                  Image(systemName: "timer")
                     .foregroundColor(.blue)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Live Refresh Interval")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Applies during live games")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Text("\(matchupRefresh)s")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Slider(
                  value: Binding(
                     get: { Double(matchupRefresh) },
                     set: { newVal in
                        matchupRefresh = max(15, min(240, Int(newVal)))
                        SmartRefreshManager.shared.scheduleNextRefresh()
                     }
                  ),
                  in: 15...240,
                  step: 1
               )
               .tint(.blue)
            }
            .padding(.vertical, 4)
            
            // Keep App Active
            HStack {
               Image(systemName: "iphone.slash")
                  .foregroundColor(.gpGreen)
                  .frame(width: 24)
               
               VStack(alignment: .leading, spacing: 2) {
                  Text("Keep App Active")
                     .font(.subheadline)
                     .fontWeight(.medium)
                  
                  Text("Prevent auto-lock while using the app")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               Toggle("", isOn: $keepAppActive)
                  .labelsHidden()
                  .onChange(of: keepAppActive) { _, newValue in
                     onKeepActiveChange(newValue)
                  }
            }
            
            // Show Eliminated Chopped Leagues
            HStack {
               Image(systemName: "eye.slash.fill")
                  .foregroundColor(.orange)
                  .frame(width: 24)
               
               VStack(alignment: .leading, spacing: 2) {
                  Text("Show Eliminated Chopped Leagues")
                     .font(.subheadline)
                     .fontWeight(.medium)
                  
                  Text("Display leagues where you've been eliminated")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               Toggle("", isOn: $showEliminatedChoppedLeagues)
                  .labelsHidden()
                  .onChange(of: showEliminatedChoppedLeagues) { _, newValue in
                     onChoppedChange(newValue)
                  }
            }
            
            // Show Eliminated Playoff Leagues
            HStack {
               Image(systemName: "trophy.slash")
                  .foregroundColor(.red)
                  .frame(width: 24)
               
               VStack(alignment: .leading, spacing: 2) {
                  Text("Show Eliminated Playoff Leagues")
                     .font(.subheadline)
                     .fontWeight(.medium)
                  
                  Text("Display regular leagues where you're out of playoffs")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               Toggle("", isOn: $showEliminatedPlayoffLeagues)
                  .labelsHidden()
                  .onChange(of: showEliminatedPlayoffLeagues) { _, newValue in
                     onPlayoffChange(newValue)
                  }
            }
         }
      } footer: {
         if isExpanded {
            Text("Configure app behavior and data refresh settings.")
         }
      }
   }
}
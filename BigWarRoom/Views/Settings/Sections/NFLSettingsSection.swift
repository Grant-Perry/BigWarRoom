//
//  NFLSettingsSection.swift
//  BigWarRoom
//
//  NFL schedule settings: week/year selection, refresh
//

import SwiftUI

struct NFLSettingsSection: View {
   @Binding var isExpanded: Bool
   @Binding var showWeekPicker: Bool
   
   let currentWeek: Int
   let currentYear: String
   let onRefresh: () async -> Void
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("NFL Settings")
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
            // Current Week
            Button {
               showWeekPicker = true
            } label: {
               HStack {
                  Image(systemName: "calendar.circle")
                     .foregroundColor(.blue)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Current Week")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Week \(currentWeek)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Image(systemName: "chevron.right")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
            }
            
            // Season Year
            Button {
               showWeekPicker = true
            } label: {
               HStack {
                  Image(systemName: "calendar")
                     .foregroundColor(.orange)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Season Year")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("\(currentYear) Season")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Image(systemName: "chevron.right")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
            }
            
            // Refresh NFL Schedule
            Button {
               Task {
                  await onRefresh()
               }
            } label: {
               HStack {
                  Image(systemName: "arrow.clockwise.circle")
                     .foregroundColor(.gpGreen)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Refresh NFL Schedule")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Force refresh current week calculation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
               }
            }
         }
      } footer: {
         if isExpanded {
            Text("Configure NFL season year, current week, and schedule settings.")
         }
      }
   }
}
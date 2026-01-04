//
//  DataManagementSection.swift
//  BigWarRoom
//
//  Cache clearing, credential management, factory reset
//

import SwiftUI

struct DataManagementSection: View {
   @Binding var isExpanded: Bool
   
   let onClearCache: () -> Void
   let onClearCredentials: () -> Void
   let onFactoryReset: () -> Void
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("Data Management")
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
            // Clear Cache
            Button(action: onClearCache) {
               HStack {
                  Image(systemName: "trash")
                     .foregroundColor(.orange)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Clear Cache")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Clear temporary app data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
               }
            }
            
            // Clear Credentials
            Button(action: onClearCredentials) {
               HStack {
                  Image(systemName: "key.slash")
                     .foregroundColor(.red)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Clear All Credentials")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                     
                     Text("Remove saved login info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
               }
            }
            
            // Factory Reset
            Button(action: onFactoryReset) {
               HStack {
                  Image(systemName: "exclamationmark.triangle")
                     .foregroundColor(.red)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Factory Reset")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                     
                     Text("Reset app to factory defaults")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
               }
            }
         }
      } footer: {
         if isExpanded {
            Text("⚠️ Use with caution. These actions cannot be undone.")
         }
      }
   }
}
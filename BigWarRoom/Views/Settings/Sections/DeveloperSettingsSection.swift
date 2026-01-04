//
//  DeveloperSettingsSection.swift
//  BigWarRoom
//
//  Debug mode, connection tests, log exports
//

import SwiftUI

struct DeveloperSettingsSection: View {
   @Binding var isExpanded: Bool
   @Binding var debugModeEnabled: Bool
   
   let espnHasCredentials: Bool
   let isTestingConnection: Bool
   
   let onTestESPN: () -> Void
   let onExportLogs: () -> Void
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("Developer")
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
            // Debug Mode
            HStack {
               Image(systemName: "ladybug")
                  .foregroundColor(.red)
                  .frame(width: 24)
               
               VStack(alignment: .leading, spacing: 2) {
                  Text("Debug Mode")
                     .font(.subheadline)
                     .fontWeight(.medium)
                  
                  Text("Show debug info and test features")
                     .font(.caption)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               Toggle("", isOn: $debugModeEnabled)
                  .labelsHidden()
            }
            
            // Test ESPN Connection
            if espnHasCredentials {
               Button(action: onTestESPN) {
                  HStack {
                     Image(systemName: "network")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                     
                     VStack(alignment: .leading, spacing: 2) {
                        Text("Test ESPN Connection")
                           .font(.subheadline)
                           .fontWeight(.medium)
                        
                        Text("Verify ESPN API access")
                           .font(.caption)
                           .foregroundColor(.secondary)
                     }
                     
                     Spacer()
                     
                     if isTestingConnection {
                        ProgressView()
                           .scaleEffect(0.8)
                     }
                  }
               }
               .disabled(isTestingConnection)
            }
            
            // Export Debug Logs
            Button(action: onExportLogs) {
               HStack {
                  Image(systemName: "doc.text")
                     .foregroundColor(.gray)
                     .frame(width: 24)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Export Debug Logs")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text("Share app logs for troubleshooting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
               }
            }
         }
      } footer: {
         if isExpanded {
            Text("Advanced settings for debugging and development.")
         }
      }
   }
}
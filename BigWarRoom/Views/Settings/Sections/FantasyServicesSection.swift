//
//  FantasyServicesSection.swift
//  BigWarRoom
//
//  ESPN and Sleeper connection management
//

import SwiftUI

struct FantasyServicesSection: View {
   @Binding var isExpanded: Bool
   
   let espnStatus: String
   let espnHasCredentials: Bool
   let sleeperStatus: String
   let sleeperHasCredentials: Bool
   
   let onDisconnectESPN: () -> Void
   let onDisconnectSleeper: () -> Void
   let onConnectDefault: () -> Void
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("Fantasy Services")
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
            // ESPN Section
            NavigationLink {
               ESPNSetupView()
            } label: {
               HStack(spacing: 12) {
                  AppConstants.espnLogo
                     .frame(width: 28, height: 28)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("ESPN Fantasy")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text(espnStatus)
                        .font(.caption)
                        .foregroundColor(espnHasCredentials ? .green : .secondary)
                  }
                  
                  Spacer()
                  
                  if espnHasCredentials {
                     Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                     
                     Button("Disconnect") {
                        onDisconnectESPN()
                     }
                     .font(.caption)
                     .foregroundColor(.red)
                     .padding(.horizontal, 8)
                     .padding(.vertical, 4)
                     .background(Color.red.opacity(0.1))
                     .cornerRadius(6)
                     .onTapGesture {
                        onDisconnectESPN()
                     }
                  }
               }
            }
            
            // Sleeper Section
            NavigationLink {
               SleeperSetupView()
            } label: {
               HStack(spacing: 12) {
                  AppConstants.sleeperLogo
                     .frame(width: 28, height: 28)
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Sleeper Fantasy")
                        .font(.subheadline)
                        .fontWeight(.medium)
                     
                     Text(sleeperStatus)
                        .font(.caption)
                        .foregroundColor(sleeperHasCredentials ? .green : .secondary)
                  }
                  
                  Spacer()
                  
                  if sleeperHasCredentials {
                     Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                     
                     Button("Disconnect") {
                        onDisconnectSleeper()
                     }
                     .font(.caption)
                     .foregroundColor(.red)
                     .padding(.horizontal, 8)
                     .padding(.vertical, 4)
                     .background(Color.red.opacity(0.1))
                     .cornerRadius(6)
                     .onTapGesture {
                        onDisconnectSleeper()
                     }
                  }
               }
            }
            
            // Default Connection
            Button {
               onConnectDefault()
            } label: {
               HStack(spacing: 12) {
                  ZStack {
                     Circle()
                        .fill(.green.opacity(0.1))
                        .frame(width: 28, height: 28)
                     
                     HStack(spacing: 2) {
                        AppConstants.espnLogo
                           .frame(width: 16, height: 16)
                        AppConstants.sleeperLogo
                           .frame(width: 16, height: 16)
                     }
                  }
                  
                  VStack(alignment: .leading, spacing: 2) {
                     Text("Default Connection (use Gp's leagues!)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                     
                     Text("Auto-connect to both ESPN and Sleeper")
                        .font(.caption)
                        .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Image(systemName: "bolt.fill")
                     .foregroundColor(.gpGreen)
                     .font(.system(size: 16))
               }
            }
            .disabled(espnHasCredentials && sleeperHasCredentials)
         }
      } footer: {
         if isExpanded {
            Text("Connect your ESPN and Sleeper accounts to access leagues and drafts.")
         }
      }
   }
}
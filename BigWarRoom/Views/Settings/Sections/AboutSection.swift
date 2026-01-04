//
//  AboutSection.swift
//  BigWarRoom
//
//  App info: version, features
//

import SwiftUI

struct AboutSection: View {
   @Binding var isExpanded: Bool
   
   var body: some View {
      Section {
         Button {
            withAnimation {
               isExpanded.toggle()
            }
         } label: {
            HStack {
               Text("About")
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
            // Features Link
            NavigationLink {
               FeaturesView()
            } label: {
               HStack {
                  Image(systemName: "info.circle")
                     .foregroundColor(.blue)
                     .frame(width: 24)
                  
                  Text("About BigWarRoom - Features")
                     .font(.subheadline)
                     .fontWeight(.medium)
               }
            }
            
            // Version
            HStack {
               Image(systemName: "number")
                  .foregroundColor(.gray)
                  .frame(width: 24)
               
               Text("Version")
                  .font(.subheadline)
                  .fontWeight(.medium)
               
               Spacer()
               
               Text(AppConstants.getVersion())
                  .font(.subheadline)
                  .foregroundColor(.secondary)
            }
         }
      }
   }
}
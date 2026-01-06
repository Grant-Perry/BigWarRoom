//
//  BracketHeader.swift
//  BigWarRoom
//
//  Bracket column header label
//

import SwiftUI

struct BracketHeader: View {
   let text: String
   
   var body: some View {
      Text(text)
         .font(.custom("BebasNeue-Regular", size: 12))
         .foregroundColor(.white.opacity(0.6))
         .frame(height: 24, alignment: .bottom)
         .padding(.bottom, 4)
   }
}
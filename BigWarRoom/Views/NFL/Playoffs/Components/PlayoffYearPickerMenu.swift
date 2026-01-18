//
//  PlayoffYearPickerMenu.swift
//  BigWarRoom
//
//  Year selection menu for playoff bracket
//

import SwiftUI

struct PlayoffYearPickerMenu: View {
    @State private var yearManager = SeasonYearManager.shared
    
    let headerFontSize: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    
    var body: some View {
        Menu {
            ForEach((2012...2026).reversed(), id: \.self) { year in
                Button(action: {
                    yearManager.selectedYear = String(year)
                }) {
                    HStack {
                        Text(String(year))
                        if String(year) == yearManager.selectedYear {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            (
                Text("\(yearManager.selectedYear) ")
                    .foregroundColor(.gpScheduledTop)
                +
                Text("NFL PLAYOFF BRACKET")
                    .foregroundColor(.white)
            )
            .font(.custom("BebasNeue-Regular", size: headerFontSize))
            .contentShape(Rectangle())
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .zIndex(10)
    }
}
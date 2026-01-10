//
//  BookPickerSheet.swift
//  BigWarRoom
//
//  Sportsbook selection sheet for odds comparison
//

import SwiftUI

struct BookPickerSheet: View {
   @Environment(\.dismiss) private var dismiss
   let odds: GameBettingOdds
   @Binding var selectedBook: String
   let onDismiss: () -> Void
   
   @State private var showingSettings = false
   
   private let columns = [
      GridItem(.flexible(), spacing: 12),
      GridItem(.flexible(), spacing: 12)
   ]
   
   var body: some View {
      VStack(spacing: 0) {
         // Header
         HStack {
            Text("Select Sportsbook")
               .font(.title3)
               .fontWeight(.bold)
            
            Spacer()
            
            Button {
               onDismiss()
               dismiss()
            } label: {
               Image(systemName: "xmark.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.secondary)
            }
         }
         .padding()
         
         Text("\(odds.awayTeamCode) @ \(odds.homeTeamCode)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
         
         Divider()
         
         // Grid container with unified background
         ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
               // Best Line first
               bookGridItem(for: .bestLine, isBestLine: true)
               
               // All other books
               if let allBookOdds = odds.allBookOdds {
                  ForEach(allBookOdds.sorted(by: { $0.book.displayName < $1.book.displayName }), id: \.book) { bookOdds in
                     bookGridItem(for: bookOdds.book, bookOdds: bookOdds)
                  }
               }
               
               // Notice about Settings - spans both columns
               HStack(spacing: 8) {
                  Image(systemName: "info.circle.fill")
                     .foregroundStyle(.blue)
                     .font(.system(size: 14))
                  
                  Text("Set your default sportsbook in ")
                     .font(.caption)
                     .foregroundStyle(.secondary)
                  +
                  Text("Settings")
                     .font(.caption)
                     .fontWeight(.semibold)
                     .foregroundStyle(.blue)
               }
               .padding(.horizontal, 12)
               .padding(.vertical, 10)
               .frame(maxWidth: .infinity, alignment: .leading)
               .background(Color(.tertiarySystemGroupedBackground))
               .cornerRadius(10)
               .onTapGesture {
                  showingSettings = true
               }
               .gridCellColumns(2)
            }
            .padding()
         }
         .background(Color(.secondarySystemGroupedBackground))
      }
      .frame(width: 600)
      .fixedSize(horizontal: false, vertical: true)
      .background(Color(.systemBackground))
      .cornerRadius(20)
      .sheet(isPresented: $showingSettings) {
         NavigationView {
            AppSettingsView(nflWeekService: NFLWeekService(apiClient: SleeperAPIClient()))
         }
      }
   }
   
   @ViewBuilder
   private func bookGridItem(for book: Sportsbook, bookOdds: BookOdds? = nil, isBestLine: Bool = false) -> some View {
      let isSelected = selectedBook == book.rawValue
      
      Button {
         selectedBook = book.rawValue
         DebugPrint(mode: .bettingOdds, "📊 Selected sportsbook: \(book.displayName)")
      } label: {
         VStack(spacing: 8) {
            // Badge and name row
            HStack(spacing: 8) {
               // For "Best Line", show the actual book's logo that has the best line
               if isBestLine, let bestBook = odds.bestMoneylineBook?.book {
                  SportsbookBadge(book: bestBook, size: 16)
               } else {
                  SportsbookBadge(book: book, size: 16)
               }
               
               Text(book.displayName)
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(isSelected ? book.primaryColor : .primary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.8)
               
               Spacer()
               
               if isSelected {
                  Image(systemName: "checkmark.circle.fill")
                     .foregroundStyle(book.primaryColor)
                     .font(.system(size: 16))
               }
            }
            
            // Odds info
            VStack(alignment: .leading, spacing: 3) {
               if isBestLine {
                  // For "Best Line", show the best odds from all books
                  if let bestMl = odds.bestMoneylineBook {
                     HStack(spacing: 4) {
                        if let favTeam = bestMl.favoriteTeamCode, let favOdds = bestMl.favoriteMoneylineDisplay {
                           Text("\(favTeam) \(favOdds)")
                              .font(.system(size: 11))
                              .foregroundStyle(.green)
                        }
                        if let dogTeam = bestMl.underdogTeamCode, let dogOdds = bestMl.underdogMoneylineDisplay {
                           Text("· \(dogTeam) \(dogOdds)")
                              .font(.system(size: 11))
                              .foregroundStyle(.orange)
                        }
                     }
                  }
               } else if let bookOdds = bookOdds {
                  // Moneyline
                  if let favTeam = bookOdds.favoriteTeamCode, let favOdds = bookOdds.favoriteMoneylineDisplay {
                     HStack(spacing: 4) {
                        Text("\(favTeam) \(favOdds)")
                           .font(.system(size: 11))
                           .foregroundStyle(.green)
                        if let dogTeam = bookOdds.underdogTeamCode, let dogOdds = bookOdds.underdogMoneylineDisplay {
                           Text("/ \(dogTeam) \(dogOdds)")
                              .font(.system(size: 11))
                              .foregroundStyle(.orange)
                        }
                     }
                  }
                  
                  // Spread & Total
                  HStack(spacing: 4) {
                     if let spread = bookOdds.spreadPoints, let spreadTeam = bookOdds.spreadTeamCode {
                        Text("\(spreadTeam) \(spread > 0 ? "+" : "")\(String(format: "%.1f", spread))")
                           .font(.system(size: 10))
                           .foregroundStyle(.secondary)
                     }
                     
                     if let total = bookOdds.totalPoints {
                        Text("· O/U \(String(format: "%.1f", total))")
                           .font(.system(size: 10))
                           .foregroundStyle(.secondary)
                     }
                  }
               }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
         }
         .padding(.horizontal, 12)
         .padding(.vertical, 10)
         .background(
            RoundedRectangle(cornerRadius: 10)
               .fill(isSelected ? book.primaryColor.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
         )
         .overlay(
            RoundedRectangle(cornerRadius: 10)
               .stroke(isSelected ? book.primaryColor : Color.clear, lineWidth: 2)
         )
      }
      .buttonStyle(.plain)
   }
}
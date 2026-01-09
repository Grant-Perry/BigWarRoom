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
   
   var body: some View {
      VStack(spacing: 0) {
         // Header
         HStack {
            Spacer()
            
            VStack(spacing: 8) {
               Text("Select Sportsbook")
                  .font(.title2)
                  .fontWeight(.bold)
               
               Text("\(odds.awayTeamCode) @ \(odds.homeTeamCode)")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
            }
            
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
         
         Divider()
         
         ScrollView {
            VStack(spacing: 12) {
               // Show "Best Line" first
               bookRow(for: .bestLine, isBestLine: true)
               
               Divider()
                  .padding(.vertical, 4)
               
               // Show all available books
               if let allBookOdds = odds.allBookOdds {
                  ForEach(allBookOdds.sorted(by: { $0.book.displayName < $1.book.displayName }), id: \.book) { bookOdds in
                     bookRow(for: bookOdds.book, bookOdds: bookOdds)
                  }
               }
            }
            .padding()
         }
      }
      .frame(width: 500, height: 450)
      .background(Color(.systemBackground))
      .cornerRadius(20)
   }
   
   @ViewBuilder
   private func bookRow(for book: Sportsbook, bookOdds: BookOdds? = nil, isBestLine: Bool = false) -> some View {
      let isSelected = selectedBook == book.rawValue
      
      Button {
         selectedBook = book.rawValue
         DebugPrint(mode: .bettingOdds, "📊 Selected sportsbook: \(book.displayName)")
      } label: {
         HStack(spacing: 12) {
            // Book badge - LARGER
            SportsbookBadge(book: book, size: 20)
            
            VStack(alignment: .leading, spacing: 4) {
               Text(book.displayName)
                  .font(.headline)
                  .foregroundStyle(isSelected ? book.primaryColor : .primary)
               
               // Show odds if available
               if isBestLine {
                  // For "Best Line", show the best odds from all books
                  if let bestMl = odds.bestMoneylineBook {
                     HStack(spacing: 6) {
                        if let favTeam = bestMl.favoriteTeamCode, let favOdds = bestMl.favoriteMoneylineDisplay {
                           Text("\(favTeam) \(favOdds)")
                              .font(.caption)
                              .foregroundStyle(.green)
                        }
                        if let dogTeam = bestMl.underdogTeamCode, let dogOdds = bestMl.underdogMoneylineDisplay {
                           Text("· \(dogTeam) \(dogOdds)")
                              .font(.caption)
                              .foregroundStyle(.orange)
                        }
                     }
                  }
               } else if let bookOdds = bookOdds {
                  // Show this book's specific odds
                  HStack(spacing: 8) {
                     // Moneyline
                     if let favTeam = bookOdds.favoriteTeamCode, let favOdds = bookOdds.favoriteMoneylineDisplay {
                        HStack(spacing: 4) {
                           Text("\(favTeam) \(favOdds)")
                              .font(.caption)
                              .foregroundStyle(.green)
                           if let dogTeam = bookOdds.underdogTeamCode, let dogOdds = bookOdds.underdogMoneylineDisplay {
                              Text("/ \(dogTeam) \(dogOdds)")
                                 .font(.caption)
                                 .foregroundStyle(.orange)
                           }
                        }
                     }
                     
                     // Spread (formatted to 2 decimal places)
                     if let spread = bookOdds.spreadPoints, let spreadTeam = bookOdds.spreadTeamCode {
                        let spreadFormatted = String(format: "%.2f", spread)
                        Text("· \(spreadTeam) \(spread > 0 ? "+" : "")\(spreadFormatted)")
                           .font(.caption)
                           .foregroundStyle(.secondary)
                     }
                     
                     // Total (formatted to 2 decimal places)
                     if let total = bookOdds.totalPoints {
                        let totalFormatted = String(format: "%.2f", total)
                        Text("· O/U \(totalFormatted)")
                           .font(.caption)
                           .foregroundStyle(.secondary)
                     }
                  }
               }
            }
            
            Spacer()
            
            // Checkmark if selected
            if isSelected {
               Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(book.primaryColor)
                  .font(.title3)
            }
         }
         .padding()
         .background(
            RoundedRectangle(cornerRadius: 12)
               .fill(isSelected ? book.primaryColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
         )
         .overlay(
            RoundedRectangle(cornerRadius: 12)
               .stroke(isSelected ? book.primaryColor : Color.clear, lineWidth: 2)
         )
      }
      .buttonStyle(.plain)
   }
}
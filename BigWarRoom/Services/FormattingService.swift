//
//  FormattingService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Centralized formatting for numbers, dates, records, percentages
//  Eliminates 200+ duplicate String(format:) calls across the codebase
//

import Foundation

/// Centralized formatting service for consistent display across the app
/// Provides static methods for common formatting patterns
struct FormattingService {
    
    // MARK: - Number Formatting
    
    /// Format a number to 1 decimal place (e.g., "12.5")
    /// Used for: fantasy points, projections, deltas
    static func formatPoints(_ value: Double) -> String {
        return String(format: "%.1f", value)
    }
    
    /// Format a number to 2 decimal places (e.g., "12.34")
    /// Used for: precise scores, percentages
    static func formatPrecise(_ value: Double) -> String {
        return String(format: "%.2f", value)
    }
    
    /// Format a percentage (e.g., "65.5%")
    static func formatPercentage(_ value: Double, includeSymbol: Bool = true) -> String {
        let formatted = String(format: "%.1f", value * 100)
        return includeSymbol ? "\(formatted)%" : formatted
    }
    
    /// Format a percentage from 0-100 range (e.g., "65.5%")
    static func formatPercentageFromWhole(_ value: Double, includeSymbol: Bool = true) -> String {
        let formatted = String(format: "%.1f", value)
        return includeSymbol ? "\(formatted)%" : formatted
    }
    
    /// Format a delta (with + or - prefix, e.g., "+5.3" or "-2.1")
    static func formatDelta(_ value: Double, decimalPlaces: Int = 1) -> String {
        let format = decimalPlaces == 1 ? "%.1f" : "%.2f"
        if value > 0 {
            return "+\(String(format: format, value))"
        } else {
            return String(format: format, value)
        }
    }
    
    /// Format yards per carry/reception/completion (e.g., "5.3 YPC")
    static func formatYardsPerAttempt(_ yards: Double, attempts: Double, suffix: String) -> String {
        guard attempts > 0 else { return "0.0 \(suffix)" }
        let ypa = yards / attempts
        return "\(formatPoints(ypa)) \(suffix)"
    }
    
    /// Format completion percentage (e.g., "65.5% COMP")
    static func formatCompletionPercentage(_ completions: Double, attempts: Double) -> String {
        guard attempts > 0 else { return "0.0% COMP" }
        let pct = (completions / attempts) * 100
        return "\(formatPoints(pct))% COMP"
    }
    
    /// Format field goal percentage (e.g., "85.7% FG")
    static func formatFieldGoalPercentage(_ made: Double, attempts: Double) -> String {
        guard attempts > 0 else { return "0.0% FG" }
        let pct = (made / attempts) * 100
        return "\(formatPoints(pct))% FG"
    }
    
    // MARK: - Record Formatting
    
    /// Format a team record (e.g., "8-5-0" or "8-5")
    static func formatRecord(wins: Int, losses: Int, ties: Int?) -> String {
        let tiesValue = ties ?? 0
        if tiesValue > 0 {
            return "\(wins)-\(losses)-\(tiesValue)"
        } else {
            return "\(wins)-\(losses)"
        }
    }
    
    /// Format a TeamRecord model
    static func formatRecord(_ record: TeamRecord) -> String {
        return formatRecord(wins: record.wins, losses: record.losses, ties: record.ties)
    }
    
    /// Calculate win percentage from record
    static func calculateWinPercentage(wins: Int, losses: Int, ties: Int?) -> Double {
        let tiesValue = ties ?? 0
        let totalGames = wins + losses + tiesValue
        guard totalGames > 0 else { return 0.0 }
        // Ties count as half a win
        let adjustedWins = Double(wins) + (Double(tiesValue) * 0.5)
        return adjustedWins / Double(totalGames)
    }
    
    /// Calculate win percentage from TeamRecord
    static func calculateWinPercentage(_ record: TeamRecord) -> Double {
        return calculateWinPercentage(wins: record.wins, losses: record.losses, ties: record.ties)
    }
    
    // MARK: - Date Formatting
    
    /// Shared date formatters (cached for performance)
    private static let gameTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    private static let gameTimeWithDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E h:mm a"  // "Sun 1:00 PM"
        return formatter
    }()
    
    private static let dayNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"  // "Sunday"
        return formatter
    }()
    
    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"  // "Jan 15"
        return formatter
    }()
    
    private static let isoFormatter = ISO8601DateFormatter()
    
    /// Format game time (e.g., "1:00 PM")
    static func formatGameTime(_ date: Date) -> String {
        return gameTimeFormatter.string(from: date)
    }
    
    /// Format game time with day (e.g., "Sun 1:00 PM")
    static func formatGameTimeWithDay(_ date: Date) -> String {
        return gameTimeWithDayFormatter.string(from: date)
    }
    
    /// Format day name (e.g., "Sunday")
    static func formatDayName(_ date: Date) -> String {
        return dayNameFormatter.string(from: date)
    }
    
    /// Format month and day (e.g., "Jan 15")
    static func formatMonthDay(_ date: Date) -> String {
        return monthDayFormatter.string(from: date)
    }
    
    /// Parse ISO8601 date string
    static func parseISO8601(_ dateString: String) -> Date? {
        return isoFormatter.date(from: dateString)
    }
    
    /// Format relative time (e.g., "2 hours ago", "5 minutes ago")
    static func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    // MARK: - Distance/Time Formatting
    
    /// Format elapsed time in seconds (e.g., "1.23s", "45.67s")
    static func formatElapsedTime(_ seconds: Double) -> String {
        return "\(formatPrecise(seconds))s"
    }
    
    /// Format file size in MB (e.g., "12.5 MB")
    static func formatFileSize(_ bytes: Double) -> String {
        let mb = bytes / (1024 * 1024)
        return "\(formatPrecise(mb)) MB"
    }
    
    // MARK: - Stats Display Formatting
    
    /// Format stat value with label (e.g., "5 TDs", "234 YDs")
    static func formatStat(_ value: Double, label: String) -> String {
        return "\(Int(value)) \(label)"
    }
    
    /// Format stat breakdown item (e.g., "5 × 6.0 = 30.0 pts")
    static func formatStatBreakdown(count: Double, pointsPerStat: Double, totalPoints: Double) -> String {
        return "\(formatPoints(count)) × \(formatPrecise(pointsPerStat)) = \(formatPrecise(totalPoints)) pts"
    }
    
    // MARK: - Ordinal Numbers
    
    /// Format ordinal numbers (e.g., "1st", "2nd", "3rd", "21st")
    static func formatOrdinal(_ number: Int) -> String {
        let suffix: String
        let ones = number % 10
        let tens = (number / 10) % 10
        
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        
        return "\(number)\(suffix)"
    }
    
    // MARK: - Color Helpers (for score-based coloring)
    
    /// Get semantic color descriptor for a score
    /// Returns: "excellent", "good", "average", "poor"
    static func getScoreQuality(_ score: Double) -> String {
        if score >= 20 { return "excellent" }
        else if score >= 12 { return "good" }
        else if score >= 8 { return "average" }
        else { return "poor" }
    }
    
    /// Get semantic color descriptor for a percentage
    static func getPercentageQuality(_ percentage: Double) -> String {
        if percentage >= 0.75 { return "excellent" }
        else if percentage >= 0.50 { return "good" }
        else if percentage >= 0.25 { return "average" }
        else { return "poor" }
    }
}

// MARK: - Convenience Extensions

extension Double {
    /// Format this double as fantasy points (1 decimal)
    var asPoints: String {
        return FormattingService.formatPoints(self)
    }
    
    /// Format this double as precise value (2 decimals)
    var asPrecise: String {
        return FormattingService.formatPrecise(self)
    }
    
    /// Format this double as percentage
    var asPercentage: String {
        return FormattingService.formatPercentage(self)
    }
    
    /// Format this double as delta
    var asDelta: String {
        return FormattingService.formatDelta(self)
    }
}

extension TeamRecord {
    /// Format this record as string
    var formatted: String {
        return FormattingService.formatRecord(self)
    }
    
    /// Calculate win percentage
    var winPercentage: Double {
        return FormattingService.calculateWinPercentage(self)
    }
}

extension Date {
    /// Format as game time
    var asGameTime: String {
        return FormattingService.formatGameTime(self)
    }
    
    /// Format as game time with day
    var asGameTimeWithDay: String {
        return FormattingService.formatGameTimeWithDay(self)
    }
    
    /// Format as day name
    var asDayName: String {
        return FormattingService.formatDayName(self)
    }
    
    /// Format as month/day
    var asMonthDay: String {
        return FormattingService.formatMonthDay(self)
    }
    
    /// Format as relative time
    var asRelativeTime: String {
        return FormattingService.formatRelativeTime(self)
    }
}
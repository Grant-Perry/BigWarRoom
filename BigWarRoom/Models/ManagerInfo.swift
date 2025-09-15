//
//  ManagerInfo.swift
//  BigWarRoom
//
//  Model representing manager display information for All Live Players
//

import Foundation
import SwiftUI

/// Model for displaying manager information in All Live Players view
struct ManagerInfo {
    let name: String
    let score: Double
    let avatarURL: URL?
    let scoreColor: Color
    let initials: String
    
    /// Initialize with automatic initials generation
    init(name: String, score: Double, avatarURL: URL? = nil, scoreColor: Color) {
        self.name = name
        self.score = score
        self.avatarURL = avatarURL
        self.scoreColor = scoreColor
        self.initials = String(name.prefix(2)).uppercased()
    }
}
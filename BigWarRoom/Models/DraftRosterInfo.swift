//
//  DraftRosterInfo.swift
//  BigWarRoom
//
//  Lightweight roster info for display on draft picks
//

import Foundation

struct DraftRosterInfo: Hashable {
    let rosterID: Int
    let ownerID: String?
    let displayName: String
}
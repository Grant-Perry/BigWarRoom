//
//  String+NameParsing.swift
//  BigWarRoom
//
//  Name parsing utilities for player names with suffix handling
//

import Foundation

extension String {
    
    /// Extract first name from full name string
    var firstName: String? {
        let components = self.split(separator: " ")
        return components.isEmpty ? nil : String(components.first!)
    }
    
    /// Extract last name from full name string, properly handling suffixes
    var lastName: String? {
        let components = self.split(separator: " ")
        
        // Need at least 2 components to have a last name
        guard components.count > 1 else { return nil }
        
        // Common name suffixes that should be ignored when extracting last name
        let suffixes: Set<String> = ["jr", "jr.", "sr", "sr.", "ii", "iii", "iv", "v"]
        let lastComponent = components.last?.lowercased() ?? ""
        
        if suffixes.contains(lastComponent) {
            // If last component is a suffix, get the second-to-last as last name
            return components.count > 2 ? String(components[components.count - 2]) : nil
        } else {
            // Normal case - last component is the actual last name
            return String(components.last!)
        }
    }
    
    /// Check if the last component is a name suffix
    var hasSuffix: Bool {
        let components = self.split(separator: " ")
        guard let lastComponent = components.last?.lowercased() else { return false }
        
        let suffixes: Set<String> = ["jr", "jr.", "sr", "sr.", "ii", "iii", "iv", "v"]
        return suffixes.contains(lastComponent)
    }
    
    /// Get the suffix if it exists
    var nameSuffix: String? {
        guard hasSuffix else { return nil }
        return String(self.split(separator: " ").last!)
    }
}
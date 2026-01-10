//
//  BracketConnectionPreferences.swift
//  BigWarRoom
//
//  Preference keys for dynamic bracket connectors
//

import SwiftUI

/// Represents a connection point on a bracket box
struct ConnectionPoint: Equatable {
    let x: CGFloat
    let y: CGFloat
    
    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// Preference key for AFC Championship connection point
struct AFCChampConnectionKey: PreferenceKey {
    static var defaultValue: ConnectionPoint? = nil
    
    static func reduce(value: inout ConnectionPoint?, nextValue: () -> ConnectionPoint?) {
        value = nextValue() ?? value
    }
}

/// Preference key for NFC Championship connection point
struct NFCChampConnectionKey: PreferenceKey {
    static var defaultValue: ConnectionPoint? = nil
    
    static func reduce(value: inout ConnectionPoint?, nextValue: () -> ConnectionPoint?) {
        value = nextValue() ?? value
    }
}

/// Preference key for AFC Super Bowl box connection point
struct AFCSBConnectionKey: PreferenceKey {
    static var defaultValue: ConnectionPoint? = nil
    
    static func reduce(value: inout ConnectionPoint?, nextValue: () -> ConnectionPoint?) {
        value = nextValue() ?? value
    }
}

/// Preference key for NFC Super Bowl box connection point
struct NFCSBConnectionKey: PreferenceKey {
    static var defaultValue: ConnectionPoint? = nil
    
    static func reduce(value: inout ConnectionPoint?, nextValue: () -> ConnectionPoint?) {
        value = nextValue() ?? value
    }
}
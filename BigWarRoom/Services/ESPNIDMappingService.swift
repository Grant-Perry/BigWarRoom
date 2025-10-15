//
//  ESPNIDMappingService.swift
//  BigWarRoom
//
//  Fallback ESPN ID mapping for players missing ESPN IDs in Sleeper database
//

import Foundation

/// ESPNIDMappingService
/// 
/// Provides fallback ESPN IDs for high-profile players who are missing ESPN IDs in Sleeper's database
final class ESPNIDMappingService {
    static let shared = ESPNIDMappingService()
    
    private let fallbackESPNIDs: [String: String] = [
        // RBs
        "BIJAN ROBINSON_ATL_RB": "4430807",
        "JAHMYR GIBBS_DET_RB": "4685392",
        "DEVON ACHANE_MIA_RB": "4685753",
        "TYLER ALLGEIER_ATL_RB": "4430123",
        "JAMES COOK_BUF_RB": "4379399",
        "TONY POLLARD_TEN_RB": "4047646",
        "NAJEE HARRIS_PIT_RB": "4240069",
        "JAVONTE WILLIAMS_DEN_RB": "4241463",
        "TRAVIS ETIENNE JR._JAX_RB": "4241389",
        "BREECE HALL_NYJ_RB": "4431195",
        "JOSH JACOBS_GB_RB": "4036215",
        "SAQUON BARKLEY_PHI_RB": "3916387",
        "DERRICK HENRY_BAL_RB": "3054773",
        
        // QBs
        "ANTHONY RICHARDSON_IND_QB": "4685888",
        "C.J. STROUD_HOU_QB": "4685889",
        "BRYCE YOUNG_CAR_QB": "4431716",
        "CALEB WILLIAMS_CHI_QB": "5075335",
        "JAYDEN DANIELS_WAS_QB": "5075336",
        "DRAKE MAYE_NE_QB": "5075337",
        "BO NIX_DEN_QB": "5075338",
        "JOSH ALLEN_BUF_QB": "3918298",
        "LAMAR JACKSON_BAL_QB": "3139477",
        "PATRICK MAHOMES_KC_QB": "3139477",
        
        // WRs
        "MARVIN HARRISON JR._ARI_WR": "5075346",
        "ROME ODUNZE_CHI_WR": "5075347",
        "MALIK NABERS_NYG_WR": "5075348",
        "BRIAN THOMAS JR._JAX_WR": "5075349",
        "LADD MCCONKEY_LAC_WR": "5075350",
        "COOPER KUPP_LAR_WR": "3045138",
        "DAVANTE ADAMS_LV_WR": "2976499",
        "TYREEK HILL_MIA_WR": "2330577",
        "STEFON DIGGS_HOU_WR": "2971618",
        "MIKE EVANS_TB_WR": "16800",
        
        // TEs
        "BROCK BOWERS_LV_TE": "5075351",
        "TRAVIS KELCE_KC_TE": "15847",
        "GEORGE KITTLE_SF_TE": "3051392",
        "MARK ANDREWS_BAL_TE": "3895856"
    ]
    
    private init() {}
    
    func getFallbackESPNID(fullName: String, team: String?, position: String?) -> String? {
        guard let team = team, let position = position else { return nil }
        
        let normalizedName = fullName.uppercased().trimmingCharacters(in: .whitespaces)
        let normalizedTeam = team.uppercased()
        let normalizedPosition = position.uppercased()
        
        // Try direct lookup first
        let directKey = "\(normalizedName)_\(normalizedTeam)_\(normalizedPosition)"
        if let espnID = fallbackESPNIDs[directKey] {
            print("🎯 FALLBACK ESPN ID: Found direct match for \(fullName) -> \(espnID)")
            return espnID
        }
        
        // Try common name variations
        let commonVariations = [
            "JAMES COOK": ["JAMES COOK", "J COOK"],
            "TONY POLLARD": ["TONY POLLARD", "T POLLARD"],
            "TRAVIS ETIENNE JR.": ["TRAVIS ETIENNE", "TRAVIS ETIENNE JR", "T ETIENNE"],
            "BIJAN ROBINSON": ["BIJHAN ROBINSON", "B ROBINSON"],
            "C.J. STROUD": ["CJ STROUD", "C.J. STROUD", "C STROUD"]
        ]
        
        for (canonicalName, variations) in commonVariations {
            for variation in variations {
                if normalizedName == variation.uppercased() {
                    let variationKey = "\(canonicalName)_\(normalizedTeam)_\(normalizedPosition)"
                    if let espnID = fallbackESPNIDs[variationKey] {
                        print("🎯 FALLBACK ESPN ID: Found via name variation '\(variation)' -> \(fullName) -> \(espnID)")
                        return espnID
                    }
                }
            }
        }
        
        print("🔍 FALLBACK ESPN ID: No mapping found for \(fullName) (\(team) \(position))")
        return nil
    }
}
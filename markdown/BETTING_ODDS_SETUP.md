# Betting Odds API Setup - Quick Start Guide

## ✅ What We Just Built

1. **Secrets Configuration** - Added `THE_ODDS_API_KEY` support
2. **BettingOddsModels.swift** - Data models for odds responses
3. **BettingOddsService.swift** - Service to fetch player props from The Odds API

---

## 🔧 Setup Instructions

### Step 1: Add Your API Key to Secrets.plist

1. Open `BigWarRoom/Resources/Secrets.plist` (or create it if it doesn't exist)
2. Add your API key:

```xml
<key>THE_ODDS_API_KEY</key>
<string>9c8535a30f4aecd701c91dfe0bc16060</string>
```

**Note:** If you don't have `Secrets.plist`, copy `Secrets.example.plist` to `Secrets.plist` and add your key.

### Step 2: Verify API Key is Loaded

The app will automatically load the key via `Secrets.theOddsAPIKey`.

---

## 🧪 Testing the Integration

### Option 1: Test via Code

You can test the service like this:

```swift
// In your ViewModel or test code
let service = BettingOddsService.shared
let player = // Get a SleeperPlayer (e.g., Josh Allen)
let odds = await service.fetchPlayerOdds(for: player, week: WeekSelectionManager.shared.currentNFLWeek)

if let odds = odds {
    print("✅ Got odds for \(odds.playerName):")
    print("   Anytime TD: \(odds.anytimeTD?.oddsString ?? "N/A")")
    print("   Rushing Yards: \(odds.rushingYards?.overUnder ?? "N/A")")
} else {
    print("❌ No odds available")
}
```

### Option 2: Test API Directly (curl)

Test if the API key works:

```bash
curl "https://api.the-odds-api.com/v4/sports/americanfootball_nfl/odds?apiKey=9c8535a30f4aecd701c91dfe0bc16060&regions=us&markets=player_props"
```

---

## 📊 What the Service Does

1. **Fetches NFL Games** - Gets all games for the specified week with player props
2. **Finds Player's Game** - Matches player's team to a game
3. **Extracts Player Props** - Searches for props with player's name
4. **Caches Results** - Caches for 1 hour to save API calls
5. **Returns Structured Data** - Clean `PlayerBettingOdds` model

---

## 🎯 Available Props

The service looks for these prop types:
- ✅ `player_anytime_td` - Anytime touchdown (most important!)
- ✅ `player_rushing_yards` - Rushing yards over/under
- ✅ `player_receiving_yards` - Receiving yards over/under
- ✅ `player_passing_yards` - Passing yards over/under
- ✅ `player_passing_tds` - Passing TDs over/under
- ✅ `player_receptions` - Receptions over/under (PPR)

---

## ⚠️ Important Notes

### API Limits (Free Tier)
- **500 requests/month**
- Each player comparison = ~1 request (fetches all games for week, cached)
- With 1-hour caching: ~250-300 comparisons/month
- Rate limit: 429 status code if exceeded

### Player Name Matching
- The API matches by player name from odds outcomes
- Uses full name, first name, or last name matching
- May need manual mapping for edge cases

### Week Date Calculation
- Currently uses simplified week → date calculation
- May need refinement for exact game dates

---

## 🚀 Next Steps

1. **Add API key** to Secrets.plist ✅ (Do this first!)
2. **Test with real players** - Try CMC, Josh Allen, Tyreek Hill
3. **Integrate into Player Comparison View** - Use odds in the comparison algorithm
4. **Handle edge cases** - Player name mismatches, missing props

---

## 📝 Usage in Player Comparison

Once set up, you can use it like this:

```swift
let bettingOddsService = BettingOddsService.shared
let currentWeek = WeekSelectionManager.shared.currentNFLWeek

// Fetch odds for a player
if let odds = await bettingOddsService.fetchPlayerOdds(for: sleeperPlayer, week: currentWeek) {
    // Use odds in comparison:
    // - odds.anytimeTD?.impliedProbability
    // - odds.rushingYards?.overUnder
    // - odds.primaryProp for display
}
```

---

## 🔍 Debugging

If odds aren't appearing:

1. **Check API key** - Verify it's in Secrets.plist
2. **Check console logs** - Service prints debug info
3. **Verify player name** - The Odds API uses full names
4. **Check game exists** - Player's team must have a game that week
5. **Check API response** - Service logs raw responses on error

---

## 🎉 Ready to Use!

Once you add the API key, the service is ready to use in your player comparison feature!



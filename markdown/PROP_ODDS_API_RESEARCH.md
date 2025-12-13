# Player Props API Research - Technical Analysis

## ⚠️ UPDATE: Prop-Odds.com Not Available for Sign-Up
**Status**: Sign-up page unavailable - need alternative API source

---

## 🎯 PRIMARY ALTERNATIVE: Odds-API.io

### Why Odds-API.io is Our Best Alternative:
- ✅ **Public Documentation Available**: https://docs.odds-api.io/examples/player-props
- ✅ **Player Props Examples**: Has specific examples for player props
- ✅ **250+ Bookmakers**: Includes DraftKings, FanDuel, BetMGM, etc.
- ✅ **Real-time Updates**: Live odds coverage
- ✅ **NFL Coverage**: Confirmed NFL player props support

### Sign-Up Location:
- **Website**: https://odds-api.io/
- **Documentation**: https://docs.odds-api.io/
- Look for "Sign Up" or "Get API Key" button

### What We Need to Verify:
- Pricing/Free tier limits
- Exact endpoint structure
- Authentication method
- Market naming (e.g., "anytime_td", "player_anytime_td")

---

## 🔄 BACKUP OPTIONS

### Option 2: The Odds API
- **Website**: https://the-odds-api.com/
- **Free Tier**: 500 requests/month
- **Documentation**: https://the-odds-api.com/docs/
- **Status**: ⚠️ Need to verify player props support
- **Sign-up**: Available on their website

### Option 3: SportsGameOdds
- **Website**: https://sportsgameodds.com/
- **Coverage**: 80+ bookmakers, 55+ leagues
- **Sign-up**: Check website for registration

### Option 4: WagerAPI
- **Website**: https://wagerapi.com/
- **Features**: Real-time player props
- **Sign-up**: Check website for registration

---

# Prop-Odds.com Original Research (For Reference)

## ✅ CONFIRMED Information

### Pricing & Limits
- **Free Starter Plan**: 1,500 requests/month
- **Algo Bettor Plan**: $44/month (after $11 first month) = 100,000 requests/month
- **Pro Bettor Plan**: $99/month = 5 million requests/month
- **Odds Update Frequency**: Every 60 seconds on all plans

### Supported Leagues
- NFL ✅ (Our primary need)
- NHL, NBA, MLB, NCAAF, WNBA, Tennis

### Supported Sportsbooks
- FanDuel ✅
- DraftKings ✅
- BetMGM ✅
- Caesars ✅
- Pinnacle
- Barstool
- BetRivers (Kambi)

### Confirmed Player Prop Markets Available

Based on research, Prop-Odds.com supports these player prop markets:

#### Touchdown-Related Props:
- ✅ **`player_anytime_td`** - Will player X score a touchdown at any point (THIS IS WHAT WE WANT!)
- ✅ **`player_first_td`** - Will player X score the first touchdown
- ✅ **`player_last_td`** - Will player X score the last touchdown
- ✅ **`player_passing_tds_over_under`** - Player passing touchdowns (Over/Under)

#### Yardage Props:
- ✅ **`player_rushing_yds_over_under`** - Player rushing yards (Over/Under)
- **`player_receiving_yds_over_under`** - Player receiving yards (Over/Under) *(implied but not explicitly confirmed)*

#### Other Markets:
- **`player_receptions_over_under`** - Receiving receptions *(implied for PPR)*
- Other passing props (completions, interceptions, etc.)

### Usage Calculation
- Each player comparison = **2 API requests** (one per player)
- Free tier: 1,500 requests = **~750 comparisons/month**
- With 1-hour caching: Could potentially serve **1,500-2,000 comparisons/month** effectively

---

## ❓ UNKNOWN / NEEDS VERIFICATION

### API Technical Details (CRITICAL - Need to Sign Up to Verify)

1. **Base URL**: Unknown
   - Typical patterns: `https://api.prop-odds.com/v1/` or similar

2. **Authentication Method**: Unknown
   - Likely API key in header: `Authorization: Bearer {API_KEY}`
   - Or query parameter: `?api_key={KEY}`
   - Need to verify exact format

3. **Endpoint Structure**: Unknown
   - Example possibilities:
     - `/beta/games/{game_id}/props`
     - `/odds/nfl/player-props/{player_id}`
     - Need actual endpoint paths

4. **Request Format**: Unknown
   - How to query by player name vs. player ID?
   - How to filter by specific market (e.g., `player_anytime_td`)?
   - Query parameters needed?

5. **Response Format**: Unknown
   - JSON structure?
   - Nested markets? Flat array?
   - How are odds formatted? (American, Decimal, Fractional?)

6. **Player Matching**: Unknown
   - How do we map Sleeper player IDs → Prop-Odds player identifiers?
   - Can we search by name? Team? Jersey number?

---

## 🎯 What We Can Provide (Based on Confirmed Markets)

### For QBs (e.g., Josh Allen):
✅ **Anytime Rushing TD** - `player_anytime_td` (if they can rush)
✅ **Passing TDs Over/Under** - `player_passing_tds_over_under`
✅ **Passing Yards Over/Under** - (likely available)
✅ **Rushing Yards Over/Under** - `player_rushing_yds_over_under` (for mobile QBs)

### For RBs (e.g., CMC):
✅ **Anytime TD** - `player_anytime_td`
✅ **Rushing Yards Over/Under** - `player_rushing_yds_over_under`
✅ **Rushing TDs Over/Under** - (likely available)

### For WRs/TEs:
✅ **Anytime TD** - `player_anytime_td`
✅ **Receiving Yards Over/Under** - (likely `player_receiving_yds_over_under`)
✅ **Receptions Over/Under** - (likely available, important for PPR)

---

## 📋 Next Steps Required

### 1. Sign Up for Free Account ⭐ (IMMEDIATE)
   - Go to: https://prop-odds.com/pricing
   - Sign up for free Starter plan
   - Get API key and access documentation

### 2. Review API Documentation
   - Find actual endpoints
   - Understand request/response formats
   - Learn authentication method
   - Understand player matching/identification

### 3. Test API Access
   - Make test requests for NFL players
   - Verify we can query specific props (e.g., `player_anytime_td`)
   - Check response structure
   - Test error handling

### 4. Verify Player Identification
   - How to map Sleeper players → Prop-Odds players?
   - Name matching? ID lookup? Manual mapping?

---

## 💡 Potential Implementation Approach

Based on typical API patterns, likely structure would be:

```swift
// Hypothetical structure (NEEDS VERIFICATION):
GET https://api.prop-odds.com/beta/games/{game_id}/props?market=player_anytime_td&api_key={KEY}

// Response might look like:
{
  "game_id": "...",
  "sportsbook": "FanDuel",
  "markets": [
    {
      "market": "player_anytime_td",
      "player_name": "Josh Allen",
      "team": "BUF",
      "yes": -150,  // American odds format
      "no": +120
    }
  ]
}
```

**BUT THIS IS SPECULATIVE** - Need actual docs!

---

## ✅ Recommendation

**Prop-Odds.com looks promising because:**
1. ✅ Confirmed support for `player_anytime_td` (our key need)
2. ✅ 3x more free requests than The Odds API (1,500 vs 500)
3. ✅ Covers all major US sportsbooks
4. ✅ Real-time odds updates (60 seconds)
5. ✅ Supports NFL comprehensively

**BUT we need to:**
1. ⚠️ Sign up and get actual API documentation
2. ⚠️ Verify exact endpoint structure
3. ⚠️ Test with real player queries
4. ⚠️ Confirm all markets we need are available

---

## 🔍 Alternative Research Path

If Prop-Odds.com documentation is unclear, consider:
- **Odds-API.io** - Another player props API (250+ bookmakers)
- **SportsGameOdds.com** - Specializes in player props
- **Contact Prop-Odds.com support** - Ask for developer documentation

---

## 📝 Notes

- Their website mentions "beta API" - may be newer/evolving
- Free tier should be sufficient for MVP/development
- Can upgrade to paid tier if user base grows
- Need to implement aggressive caching (1 hour) to maximize free tier value


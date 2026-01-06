// ... existing code ...
    private var playoffBracketContent: some View {
        if let service = playoffBracketService {
            VStack(spacing: 0) {
                // Header with week picker
                playoffBracketHeader
                    .padding(.top, 12)
                
                // Bracket view - REMOVED bullshit offset
                NFLPlayoffBracketView(
                    weekSelectionManager: weekSelectionManager,
                    appLifecycleManager: AppLifecycleManager.shared,
                    fantasyViewModel: nil, // TODO: Pass fantasy VM for player highlighting
                    initialSeason: Int(SeasonYearManager.shared.selectedYear)
                )
            }
        } else {
            ProgressView("Loading playoffs...")
// ... existing code ...
import SwiftUI

struct MissionSplashView: View {
    @Binding var showSplash: Bool
    @State private var splashProgress: Double = 0.0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Hero mission control logo/art/animation here if you want
            
            Text("MISSION CONTROL")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.gpGreen, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.bottom, 2)
            
            Text("Initializing your fantasy empire…")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            
            MatchupsHubLoadingProgressBarView(progress: splashProgress)
                .padding(.horizontal, 52)
                .padding(.vertical, 24)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            withAnimation(.linear(duration: 3.0)) {
                splashProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                showSplash = false
            }
        }
    }
}
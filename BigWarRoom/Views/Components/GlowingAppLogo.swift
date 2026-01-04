import SwiftUI

struct GlowingAppLogo: View {
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        ZStack {
            glowLayers
            mainLogoBackground
            logoIcon
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
        }
    }
    
    private var glowLayers: some View {
        ForEach(0..<3) { index in
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120 + CGFloat(index * 10), height: 120 + CGFloat(index * 10))
                .blur(radius: CGFloat(5 + index * 5))
                .opacity(glowIntensity * (1.0 - Double(index) * 0.3))
        }
    }
    
    private var mainLogoBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.purple.opacity(0.1),
                        Color.blue.opacity(0.2)
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 60
                )
            )
            .frame(width: 100, height: 100)
    }
    
    private var logoIcon: some View {
        Image(systemName: "brain.head.profile.fill")
            .font(.system(size: 40, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
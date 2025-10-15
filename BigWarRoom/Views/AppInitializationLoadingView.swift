//
//  AppInitializationLoadingView.swift
//  BigWarRoom
//
//  🔥 SOLUTION: Central loading screen shown during app initialization
//

import SwiftUI

struct AppInitializationLoadingView: View {
    @ObservedObject var initManager: AppInitializationManager
    
    var body: some View {
        ZStack {
            // Background
            Image("BG7")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.4)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 40) {
                // App Logo/Title - REMOVED BigWarRoom text
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 80))
                        .foregroundColor(.gpOrange)
                    
                    Text("Loading your fantasy empire...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Loading Progress
                VStack(spacing: 24) {
                    // 🔥 FIXED: Use orbs loading animation
                    FantasyLoadingIndicator()
                        .scaleEffect(1.5)
                    
                    // Progress Bar
                    VStack(spacing: 12) {
                        Text(initManager.currentLoadingStage.displayText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        ProgressView(value: initManager.loadingProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .gpOrange))
                            .frame(height: 8)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                            .padding(.horizontal, 20)
                        
                        Text("\(Int(initManager.loadingProgress * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Error State
                if let errorMessage = initManager.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Initialization Failed")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button("Retry") {
                            Task {
                                await initManager.retry()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    AppInitializationLoadingView(initManager: AppInitializationManager.shared)
        .preferredColorScheme(.dark)
}
//
//  AppInitializationLoadingView.swift
//  BigWarRoom
//
//  🔥 SOLUTION: Central loading screen shown during app initialization
//

import SwiftUI

struct AppInitializationLoadingView: View {
    @State var initManager: AppInitializationManager
    
    var body: some View {
        ZStack {
            // Background
            Image("BG7")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.4)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 40) {
                // App Logo/Title
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 80))
                        .foregroundColor(.gpOrange)
                    
                    Text("Loading your fantasy empire...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Error State (show this first if there's an error)
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
                        
                        // Skip button for development
                        Button("Skip to App") {
                            initManager.isInitialized = true
                            initManager.isLoading = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    .padding(.top, 20)
                } else {
                    // Loading Progress (only show if no error)
                    VStack(spacing: 24) {
                        // Spinning orbs
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
                        
                        // 🔥 DEBUG: Force initialize button if stuck
                        if !initManager.isLoading && initManager.loadingProgress == 0.0 {
                            VStack(spacing: 12) {
                                Text("Stuck? Try manual initialization")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Button("Force Initialize") {
                                    Task {
                                        await initManager.initializeApp()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // Version at bottom - overlaid with background for visibility
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Text("Version: \(AppConstants.getVersion())")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(.bottom, 50)
                        .padding(.trailing, 20)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            logInfo("AppInitializationLoadingView appeared", category: "LoadingView")
            logInfo("Current stage: \(initManager.currentLoadingStage.displayText)", category: "LoadingView")
            logInfo("Progress: \(initManager.loadingProgress)", category: "LoadingView")
            logInfo("Error: \(initManager.errorMessage ?? "none")", category: "LoadingView")
            logInfo("IsLoading: \(initManager.isLoading), IsInitialized: \(initManager.isInitialized)", category: "LoadingView")
        }
    }
}

#Preview {
    AppInitializationLoadingView(initManager: AppInitializationManager.shared)
        .preferredColorScheme(.dark)
}

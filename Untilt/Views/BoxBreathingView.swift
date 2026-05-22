import SwiftUI

private struct RippleCircleBox: View {
    let color: Color
    let delay: Double
    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(color.opacity(animating ? 0 : 0.45), lineWidth: 2)
            .frame(width: 192, height: 192)
            .scaleEffect(animating ? 2.4 : 1.0)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.2)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    animating = true
                }
            }
    }
}

struct BoxBreathingView: View {
    @State private var phase = 0
    @State private var count = 1
    @State private var scale: CGFloat = 0.8
    @State private var showCompletionAlert = false
    @State private var breathingTimer: Timer?
    @State private var completionTimer: Timer?
    @Environment(\.openURL) var openURL
    
    var onComplete: (() -> Void)?

    let phases = ["Breathe In Through the Nose", "Hold", "Breathe Out Through the Mouth", "Hold"]
    
    let phaseFont = [25,25,25,25]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 150) {
                // Breathing icon with timer
                ZStack {
                    Circle()
                        .fill(UntiltTheme.Color.lavender700)
                        .frame(width: 192, height: 192)
                        .scaleEffect(scale)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    // Icon based on phase
                    Group {
                        switch phase {
                        case 0: // Breathe In - wind icon
                            Image(systemName: "nose")
                                .font(.system(size: 64, weight: .regular))
                                .foregroundColor(.white)
                        case 1: // Hold - stop hand
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 64, weight: .regular))
                                .foregroundColor(.white)
                        case 2: // Breathe Out - lungs icon
                            Image(systemName: "wind")
                                .font(.system(size: 64, weight: .regular))
                                .foregroundColor(.white)
                        case 3: // Hold - stop hand
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 64, weight: .regular))
                                .foregroundColor(.white)
                        default:
                            EmptyView()
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .id("icon-\(phase)")

                }

                
                // Phase text

                    Text(phases[phase])
                        .font(.system(size: CGFloat(phaseFont[phase]), weight: .regular))
                        .foregroundStyle(Color(red: 67/255, green: 45/255, blue: 92/255))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                        .id("phase-\(phase)")


                // Progress indicators
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == phase ? Color(red: 67/255, green: 45/255, blue: 92/255) : Color(red: 67/255, green: 45/255, blue: 92/255).opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .onAppear {
            startBreathingCycle()
            startCompletionTimer()
        }
        .onDisappear {
            breathingTimer?.invalidate()
            completionTimer?.invalidate()
        }
        .alert("Great Work!", isPresented: $showCompletionAlert) {
            Button("Go to Home") {
                onComplete?()
            }
            Button("Continue to App") {
                // This will be triggered from the Shortcuts app
                // You can pass a URL scheme to continue
                continueToOriginalApp()
            }
        } message: {
            Text("You've completed 2 minutes of box breathing. How would you like to proceed?")
        }
    }

    private func startBreathingCycle() {
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            withAnimation {
                if count == 4 {
                    count = 1
                    phase = (phase + 1) % 4
                    updateScale()
                } else {
                    count += 1
                }
            }
        }

        // Initial scale
        updateScale()
    }
    
    private func startCompletionTimer() {
        // Show alert after 2 minutes (120 seconds)
        completionTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: false) { _ in
            showCompletionAlert = true
            breathingTimer?.invalidate()
        }
    }
    
    private func continueToOriginalApp() {
        // Check if there's a return URL from Shortcuts
        if let urlString = UserDefaults.standard.string(forKey: "returnAppURL"),
           let url = URL(string: urlString) {
            openURL(url)
            // Clear the stored URL
            UserDefaults.standard.removeObject(forKey: "returnAppURL")
        }
    }

    private func updateScale() {
        withAnimation(.easeInOut(duration: 4.0)) {
            scale = (phase == 0 || phase == 1) ? 1.5 : 0.8
        }
    }
}

#Preview {
    BoxBreathingView()
}

//  BoxBreathingView.swift
//  Untilt
//
//  Created by Abraham Rubin on 5/11/26.
//


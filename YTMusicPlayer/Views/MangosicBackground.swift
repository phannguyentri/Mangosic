import SwiftUI

struct MangosicBackground: View {
    var body: some View {
        ZStack {
            // 1. Deep Base Background
            Theme.background
                .ignoresSafeArea()
            
            // 2. Top-down Light Leak / Aurora Effect
            GeometryReader { proxy in
                ZStack {
                    // Main Top Glow (Yellow -> Orange)
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [Theme.primaryStart.opacity(0.8), Theme.primaryEnd.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: proxy.size.width * 1.8, height: proxy.size.height * 1.3) // Extended height
                        .blur(radius: 120) // Smoother blur
                        .opacity(0.18) // Slightly clearer visibility, but kept subtle
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.1) // Pushed down slightly
                        
                    // Secondary Top-Left Glow (Subtle Variation)
                    Circle()
                        .fill(Theme.primaryEnd)
                        .frame(width: proxy.size.width * 1.0)
                        .blur(radius: 100)
                        .opacity(0.1)
                        .position(x: proxy.size.width * 0.2, y: proxy.size.height * 0.1)
                        
                    // Fade out mask (Pushed down to allow light to reach further)
                    LinearGradient(
                        colors: [.clear, Theme.background.opacity(0.9)],
                        startPoint: UnitPoint(x: 0.5, y: 0.6),
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    MangosicBackground()
}

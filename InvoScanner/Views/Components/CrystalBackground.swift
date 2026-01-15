import SwiftUI

// MARK: - Crystal Background (iOS 26 Liquid Glass)

/// iOS 26 tarzı dinamik arka plan
/// Liquid Glass efekti için yumuşak renk geçişleri
struct CrystalBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Taban: Koyu Arka Plan
            Color(.black)
                .ignoresSafeArea()
            
            // iOS 26 Liquid Glass Katmanları
            ZStack {
                // Sol Üst - Mor/Mavi
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.indigo.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 450, height: 450)
                    .blur(radius: 80)
                    .offset(x: animate ? -80 : 80, y: animate ? -80 : 40)
                
                // Sağ Alt - Turkuaz/Mavi
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 90)
                    .offset(x: animate ? 120 : -40, y: animate ? 180 : 20)
                
                // Orta - Parlak Macenta
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 350, height: 350)
                    .blur(radius: 100)
                    .offset(x: animate ? -40 : 120, y: animate ? 60 : -40)
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate)
            
            // Subtle Grain Overlay
            Rectangle()
                .fill(.white.opacity(0.015))
                .ignoresSafeArea()
        }
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    CrystalBackground()
}


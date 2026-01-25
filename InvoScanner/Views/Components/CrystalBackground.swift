import SwiftUI

/// Dinamik hareketli arka plan efekti
struct CrystalBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Taban: Koyu renk
            Color(.black)
                .ignoresSafeArea()
            
            // Hareketli ışık katmanları
            ZStack {
                // Mor/Mavi ışık
                Circle()
                    .fill(Color.indigo.opacity(0.4))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: animate ? -100 : 100, y: animate ? -100 : 50)
                
                // Turkuaz ışık
                Circle()
                    .fill(Color.cyan.opacity(0.35))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: animate ? 100 : -50, y: animate ? 200 : 0)
                
                // Macenta ışık
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 120)
                    .offset(x: animate ? -50 : 150, y: animate ? 50 : -50)
            }
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animate)
            
            // Doku (Grain) efekti
            Rectangle()
                .fill(.white.opacity(0.02))
                .ignoresSafeArea()
        }
        .onAppear {
            animate = true
        }
    }
}

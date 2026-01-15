import SwiftUI

// MARK: - Liquid Glass Card

/// iOS 26 tarzı cam kart bileşeni
/// Tüm ekranlarda tutarlı kullanım için tasarlandı
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 24
    
    init(padding: CGFloat = 20, cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Liquid Glass Button

/// iOS 26 tarzı cam buton
struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let color: Color
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, color: Color = .blue, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.bold())
                }
                Text(title)
                    .font(.body.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Liquid Glass Section Header

/// iOS 26 tarzı bölüm başlığı
struct LiquidGlassSectionHeader: View {
    let title: String
    let icon: String?
    
    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        CrystalBackground()
        
        VStack(spacing: 20) {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    LiquidGlassSectionHeader("Örnek Bölüm", icon: "star.fill")
                    Text("Bu bir liquid glass kart örneğidir.")
                        .foregroundStyle(.white)
                }
            }
            
            LiquidGlassButton("Devam Et", icon: "arrow.right", color: .cyan) {
                print("Tapped")
            }
        }
        .padding()
    }
}

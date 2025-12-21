import Foundation
import CoreGraphics

/// Herhangi bir kaynaktan (PDF, Vision vb.) ayıklanmış normale edilmiş metin bloğunu temsil eder
struct TextBlock: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let frame: CGRect // Normalize edilmiş koordinatlar (0..1)
    
    // Bu bloğun kabaca başka bir blokla aynı satırda olup olmadığını kontrol eden yardımcı fonksiyon
    func isSameLine(as other: TextBlock, threshold: CGFloat = 0.02) -> Bool {
        return abs(self.frame.midY - other.frame.midY) < threshold
    }
}

import Foundation
import CoreGraphics

// MARK: - Layout Map

/// Belgenin 2D uzamsal haritası
/// Sol ve sağ kolonları, tam genişlikli blokları ve zone bilgilerini tutar
struct LayoutMap {
    
    // MARK: - Properties
    
    /// Sol kolondaki semantik bloklar (Satıcı, Alıcı, ETTN genellikle burada)
    var leftColumn: [SemanticBlock]
    
    /// Sağ kolondaki semantik bloklar (Fatura No, Tarih, Toplamlar genellikle burada)
    var rightColumn: [SemanticBlock]
    
    /// Tam genişlikli bloklar (Tablolar, uzun açıklamalar)
    var fullWidthBlocks: [SemanticBlock]
    
    // MARK: - Computed Properties
    
    /// Tüm bloklar (konum fark etmeksizin)
    var allBlocks: [SemanticBlock] {
        leftColumn + rightColumn + fullWidthBlocks
    }
    
    /// Belirli bir etikete sahip blokları döndürür
    func blocks(withLabel label: BlockLabel) -> [SemanticBlock] {
        allBlocks.filter { $0.label == label }
    }
    
    /// Sol kolondaki belirli bir etikete sahip ilk blok
    func leftBlock(withLabel label: BlockLabel) -> SemanticBlock? {
        leftColumn.first { $0.label == label }
    }
    
    /// Sağ kolondaki belirli bir etikete sahip ilk blok
    func rightBlock(withLabel label: BlockLabel) -> SemanticBlock? {
        rightColumn.first { $0.label == label }
    }
    
    // MARK: - Zone-Based Access
    
    /// Üst bölgedeki bloklar (Y < 0.35)
    var topBlocks: [SemanticBlock] {
        allBlocks.filter { $0.center.y < 0.35 }
    }
    
    /// Alt bölgedeki bloklar (Y > 0.65)
    var bottomBlocks: [SemanticBlock] {
        allBlocks.filter { $0.center.y > 0.65 }
    }
    
    /// Orta bölgedeki bloklar (0.35 <= Y <= 0.65)
    var middleBlocks: [SemanticBlock] {
        allBlocks.filter { $0.center.y >= 0.35 && $0.center.y <= 0.65 }
    }
    
    // MARK: - Factory
    
    /// BlockClusterer çıktısından LayoutMap oluşturur
    static func from(clusteredBlocks: [SemanticBlock]) -> LayoutMap {
        var left: [SemanticBlock] = []
        var right: [SemanticBlock] = []
        var fullWidth: [SemanticBlock] = []
        
        for block in clusteredBlocks {
            let box = block.frame
            
            // Geniş bloklar (width > 0.6) tam genişlik sayılır
            if box.width > 0.6 {
                fullWidth.append(block)
            } else if box.midX < 0.5 {
                left.append(block)
            } else {
                right.append(block)
            }
        }
        
        // Y koordinatına göre sırala
        left.sort { $0.center.y < $1.center.y }
        right.sort { $0.center.y < $1.center.y }
        fullWidth.sort { $0.center.y < $1.center.y }
        
        return LayoutMap(
            leftColumn: left,
            rightColumn: right,
            fullWidthBlocks: fullWidth
        )
    }
    
    // MARK: - Debug
    
    /// Haritayı okunabilir formatta yazdırır
    func debugPrint() {
        print("=== Layout Map ===")
        print("Sol Kolon (\(leftColumn.count) blok):")
        for (i, block) in leftColumn.enumerated() {
            print("  [\(i)] [\(block.label)] Y:\(String(format: "%.2f", block.center.y)) - \(block.text.prefix(50))...")
        }
        print("Sağ Kolon (\(rightColumn.count) blok):")
        for (i, block) in rightColumn.enumerated() {
            print("  [\(i)] [\(block.label)] Y:\(String(format: "%.2f", block.center.y)) - \(block.text.prefix(50))...")
        }
        print("Tam Genişlik (\(fullWidthBlocks.count) blok):")
        for (i, block) in fullWidthBlocks.enumerated() {
            print("  [\(i)] [\(block.label)] Y:\(String(format: "%.2f", block.center.y)) - \(block.text.prefix(50))...")
        }
        print("==================")
    }
}

import Foundation
import CoreGraphics

struct SupplierStrategy: ExtractionStrategy {
    typealias ResultType = String
    
    func extract(from blocks: [TextBlock]) -> String? {
        // Sayfanın üst %20'lik kısmını filtrele
        let topBlocks = blocks.filter { $0.frame.maxY < 0.25 } // biraz esnek %25
        
        let corporateSuffixes = ["A.Ş.", "LTD.", "ŞTİ.", "TİC.", "SAN.", "ANONİM", "LİMİTED"]
        
        var bestCandidate: String?
        var longestCount = 0
        
        for block in topBlocks {
            let text = block.text.uppercased()
            
            // Kurumsal sonekleri kontrol et
            for suffix in corporateSuffixes {
                if text.contains(suffix) {
                    // Sezgisel: Kurumsal ad genellikle tam satırdır
                    if text.count > longestCount {
                        longestCount = text.count
                        bestCandidate = block.text // Orijinal hali döndür
                    }
                }
            }
        }
        
        return bestCandidate
    }
}

import Foundation

class InvoiceParser {
    
    private let resolver = StrategyResolver()
    
    /// Metin ve/veya bloklardan faturayı ayrıştırır
    func parse(text: String = "", blocks: [TextBlock]? = nil) -> Invoice {
        
        // 1. Normalizasyon: OCR hatası temizliği ve standartlaştırma
        // Eğer text boşsa bloklardan elde etmeye çalış, o da yoksa boş string
        let rawText = text.isEmpty ? (blocks?.map { $0.text }.joined(separator: "\n") ?? "") : text
        let normalizedText = TextNormalizer.normalize(rawText)
        
        // 2. Strateji Seçimi: Marka tespiti veya Generic
        let strategy = resolver.resolve(text: normalizedText)
        
        print("Parser: Seçilen Strateji -> \(type(of: strategy))")
        
        // 3. Ayıklama
        let invoice = strategy.extract(text: normalizedText, rawBlocks: blocks)
        
        return invoice
    }
    
    // Geriye dönük uyumluluk (Eski testler ve çağrılar için)
    func parse(blocks: [TextBlock]) -> Invoice {
        return parse(text: "", blocks: blocks)
    }
}

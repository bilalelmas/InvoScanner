import Foundation

class StrategyResolver {
    
    // Kayıtlı stratejiler (Sıra önemlidir: Özelleşmiş -> Genel)
    private let strategies: [InvoiceExtractionStrategy]
    
    init() {
        self.strategies = [
            TrendyolStrategy(),
            HepsiburadaStrategy(),
            GenericStrategy() // Fallback
        ]
    }
    
    /// Metne uygun stratejiyi bulur ve döndürür.
    func resolve(text: String) -> InvoiceExtractionStrategy {
        // Normalize metin üzerinden kontrol et
        for strategy in strategies {
            if strategy.canHandle(text: text) {
                return strategy
            }
        }
        
        // Hiçbiri uymazsa Generic (zaten listede olmalı ama garanti olsun)
        return GenericStrategy()
    }
}

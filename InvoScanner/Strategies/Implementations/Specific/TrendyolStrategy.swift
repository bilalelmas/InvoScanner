import Foundation

struct TrendyolStrategy: InvoiceExtractionStrategy {
    
    // Algılama anahtar kelimeleri
    private let keywords = ["TRENDYOL", "DSM GRUP", "DSMGRUP"]
    
    // Alt bileşenler (Fallback için)
    private let genericFallback = GenericStrategy()
    
    func canHandle(text: String) -> Bool {
        for keyword in keywords {
            if text.contains(keyword) { return true }
        }
        return false
    }
    
    func extract(text: String, rawBlocks: [TextBlock]?) -> Invoice {
        // Trendyol için özelleşmiş ayıklama
        // 1. Önce Generic'i çalıştır (Temel alanlar için)
        // 2. Ardından Trendyol'a özel düzeltmeleri uygula
        
        var invoice = genericFallback.extract(text: text, rawBlocks: rawBlocks)
        
        // Trendyol Özel Kuralları
        
        // Kural 1: Satıcı ismi genellikle sabittir ("DSM GRUP...")
        // Ancak Marketplace satıcısı ise farklı olabilir.
        // Eğer metin "DSM GRUP" içeriyorsa ve başka belirgin satıcı yoksa
        if text.contains("DSM GRUP") {
            // Şimdilik basitçe sabitliyoruz, marketplace ayrımı V1
            invoice.supplierName = "DSM GRUP DANIŞMANLIK İLETİŞİM VE SATIŞ TİC.A.Ş."
        }
        
        // Kural 2: Tutar Önceliği
        // Generic zaten "ODENECEK TUTAR" öncelikli çalışıyor.
        // Trendyol'da ekstra "Cüzdan" vb. indirim satırları olabilir, "ODENECEK TUTAR" daima doğrudur.
        
        return invoice
    }
}

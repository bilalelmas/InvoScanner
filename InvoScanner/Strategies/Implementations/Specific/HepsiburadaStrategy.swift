import Foundation

struct HepsiburadaStrategy: InvoiceExtractionStrategy {
    
    private let keywords = ["D-MARKET", "HEPSIBURADA", "H BILISIM"]
    private let genericFallback = GenericStrategy()
    
    func canHandle(text: String) -> Bool {
        for keyword in keywords {
            if text.contains(keyword) { return true }
        }
        return false
    }
    
    func extract(text: String, rawBlocks: [TextBlock]?) -> Invoice {
        var invoice = genericFallback.extract(text: text, rawBlocks: rawBlocks)
        
        // Hepsiburada Özel Mantığı
        
        // Satıcı Tespiti: Platform (D-Market) mi, Pazaryeri mi?
        if text.contains("D-MARKET") || text.contains("D MARKET") {
            // Platform Satışı
            invoice.supplierName = "D-MARKET ELEKTRONİK HİZMETLER VE TİC. A.Ş."
        } else {
            // Pazaryeri satıcısı: Generic ayıklamaya güven veya geliştir
        }
        
        // ETTN Bölünmüş Satır Kontrolü (Hepsiburada klasiği)
        // Generic Strategy ETTN Regex'i zaten basit boşlukları (multiline değilse) handle edebilir.
        // Ancak satır sonu bölünmesini Generic içinde handle ediyor olmalıyız (clean text ile).
        
        return invoice
    }
}

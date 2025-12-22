import Foundation

struct HepsiburadaStrategy: InvoiceExtractionStrategy {
    
    private let keywords = ["D-MARKET", "HEPSIBURADA", "H BILISIM"]
    private let genericFallback = GenericStrategy()
    private let supplierExtractorV2 = SupplierExtractorV2()
    
    func canHandle(text: String) -> Bool {
        for keyword in keywords {
            if text.contains(keyword) { return true }
        }
        return false
    }
    
    func extract(text: String, rawBlocks: [TextBlock]?) -> Invoice {
        var invoice = genericFallback.extract(text: text, rawBlocks: rawBlocks)
        
        // V1: Hepsiburada Platform vs Marketplace Ayrımı
        
        // 1. SellerProfile kontrolü (Platform satışı mı?)
        if let profile = SellerProfileRegistry.findProfile(for: text),
           profile.name == "D-MARKET",
           let forcedName = profile.forceSupplierName {
            
            // Platform satışı: D-MARKET kendisi satıyor
            // Ancak VKN bloğundan başka bir satıcı çıkarsa = Marketplace
            let taxBlockSupplier = supplierExtractorV2.extract(from: text)
            
            if let detectedSupplier = taxBlockSupplier,
               !detectedSupplier.contains("D-MARKET") && !detectedSupplier.contains("D MARKET") {
                // Marketplace satışı: Tax Block'tan gelen satıcıyı kullan
                invoice.supplierName = detectedSupplier
                print("HepsiburadaStrategy: Marketplace satışı tespit edildi: \(detectedSupplier)")
            } else {
                // Platform satışı
                invoice.supplierName = forcedName
                print("HepsiburadaStrategy: Platform satışı (D-MARKET)")
            }
        }
        
        return invoice
    }
}


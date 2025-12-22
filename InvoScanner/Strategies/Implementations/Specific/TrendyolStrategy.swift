import Foundation

struct TrendyolStrategy: InvoiceExtractionStrategy {
    
    // Algılama anahtar kelimeleri
    private let keywords = ["TRENDYOL", "DSM GRUP", "DSMGRUP"]
    
    // Alt bileşenler
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
        
        // V1: Trendyol Platform vs Marketplace Ayrımı
        
        // 1. SellerProfile kontrolü (Platform satışı mı?)
        if let profile = SellerProfileRegistry.findProfile(for: text),
           profile.name == "DSM GRUP",
           let forcedName = profile.forceSupplierName {
            
            // Platform satışı: DSM GRUP kendisi satıyor
            // Ancak VKN bloğundan başka bir satıcı çıkarsa = Marketplace
            let taxBlockSupplier = supplierExtractorV2.extract(from: text)
            
            if let detectedSupplier = taxBlockSupplier,
               !detectedSupplier.contains("DSM") {
                // Marketplace satışı: Tax Block'tan gelen satıcıyı kullan
                invoice.supplierName = detectedSupplier
                print("TrendyolStrategy: Marketplace satışı tespit edildi: \(detectedSupplier)")
            } else {
                // Platform satışı
                invoice.supplierName = forcedName
                print("TrendyolStrategy: Platform satışı (DSM GRUP)")
            }
        }
        
        return invoice
    }
}


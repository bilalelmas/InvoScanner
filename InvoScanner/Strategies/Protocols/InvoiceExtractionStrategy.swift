import Foundation

/// Fatura düzeyinde ayıklama yapan stratejilerin protokolü.
/// Her strateji (Trendyol, Hepsiburada, Standart) bu protokolü uygular.
protocol InvoiceExtractionStrategy {
    
    /// Stratejinin bu metni işleyip işleyemeyeceğini belirler.
    /// - Parameter text: Normalize edilmiş tam metin.
    func canHandle(text: String) -> Bool
    
    /// Verilen metinden (ve varsa bloklardan) faturayı ayıklar.
    /// - Parameters:
    ///   - text: Normalize edilmiş metin.
    ///   - rawBlocks: OCR blokları (varsa).
    /// - Returns: Ayıklanan Fatura nesnesi.
    func extract(text: String, rawBlocks: [TextBlock]?) -> Invoice
}

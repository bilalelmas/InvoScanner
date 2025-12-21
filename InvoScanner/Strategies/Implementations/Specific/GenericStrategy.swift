import Foundation

/// Genel e-Arşiv faturaları için varsayılan strateji.
/// Mevcut Alan Stratejilerini (ETTN, Date, Amount, Supplier) kullanır.
struct GenericStrategy: InvoiceExtractionStrategy {
    
    // Alt bileşenler (Mevcut field stratejileri - Uzamsal Fallback için)
    private let ettnStrategy = ETTNStrategy()
    private let dateStrategy = DateStrategy()
    private let amountStrategy = AmountStrategy()
    private let supplierStrategy = SupplierStrategy()
    
    func canHandle(text: String) -> Bool {
        return true
    }
    
    func extract(text: String, rawBlocks: [TextBlock]?) -> Invoice {
        var invoice = Invoice()
        invoice.rawBlocks = rawBlocks ?? []
        
        // 1. Text-Based Extraction (Regex - Öncelikli)
        invoice.ettn = extractETTN(text: text)
        invoice.invoiceNumber = extractInvoiceNumber(text: text)
        invoice.date = extractDate(text: text)
        invoice.totalAmount = extractAmount(text: text)
        invoice.supplierName = extractSupplier(text: text) // Regex ile zor, fallback'e kalabilir
        
        // 2. Fallback: Coordinate-Based Extraction (Eksik alanlar için)
        if let blocks = rawBlocks, !blocks.isEmpty {
            if invoice.ettn == nil { invoice.ettn = ettnStrategy.extract(from: blocks) }
            // Invoice No için mevcut bir stratejimiz yoktu, koordinat fallback yapılamıyor.
            if invoice.date == nil { invoice.date = dateStrategy.extract(from: blocks) }
            if invoice.totalAmount == nil { invoice.totalAmount = amountStrategy.extract(from: blocks) }
            if invoice.supplierName == nil { invoice.supplierName = supplierStrategy.extract(from: blocks) }
        }
        
        return invoice
    }
    
    // MARK: - Regex Helpers
    
    private func extractETTN(text: String) -> UUID? {
        // Strict UUID Pattern
        let pattern = "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
        if let range = text.range(of: pattern, options: .regularExpression) {
            return UUID(uuidString: String(text[range]))
        }
        return nil
    }
    
    private func extractInvoiceNumber(text: String) -> String? {
        // Öncelik: FATURA NO > BELGE NO
        // Fatura No: (FATURA|BELGE)\s*(NO|NUMARASI)\s*[:\-]?\s*([A-Z0-9]{10,})
        // Sipariş No tuzağından kaçın (SIPARIS yakınlığında olmamalı - Regex ile tam kontrol zor ama basitce bakılabilir)
        
        let patterns = [
            "(FATURA|BELGE)\\s*(NO|NUMARASI|SERI)\\s*[:\\.]?\\s*([A-Z0-9]{3,})", // Genişletilmiş
            "([A-Z]{2,4}[0-9]{10,})" // Fallback: Doğrudan format AAA2023...
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                // Grup sayısı değişebilir, son grubu almaya çalışalım
                let rangeIndex = match.numberOfRanges - 1
                if rangeIndex > 0, let range = Range(match.range(at: rangeIndex), in: text) {
                     return String(text[range])
                }
            }
        }
        return nil
    }
    
    private func extractDate(text: String) -> Date? {
        // Düzenleme Tarihi: 21-12-2025
        let patterns = [
            "(DUZENLEME|FATURA)\\s*TARIHI\\s*[:]?\\s*([0-9]{2}[\\.-][0-9]{2}[\\.-][0-9]{4})",
            "([0-9]{2}[\\.-][0-9]{2}[\\.-][0-9]{4})" // Gevşek tarih arama (sadece format)
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                // Grup 2 (Tarih) varsa onu al, yoksa Grup 1 (Tarih tek başına ise)
                let rangeIndex = match.numberOfRanges > 2 ? 2 : 1
                if let range = Range(match.range(at: rangeIndex), in: text) {
                    let dateStr = String(text[range])
                    return parseDate(dateStr)
                }
            }
        }
        return nil
    }
    
    private func extractAmount(text: String) -> Decimal? {
        // ODENECEK TUTAR > GENEL TOPLAM
        let prioritizedKeywords = ["ODENECEK TUTAR", "GENEL TOPLAM", "TOPLAM"]
        
        for keyword in prioritizedKeywords {
            // Regex: KEYWORD ... : ... 1.250,00 ... (TL|TRY)
            // Sayı formatı: 1.234,56 veya 1234.56
            let pattern = "\(keyword).*?([0-9]+[\\.,][0-9]{2,})" // Basitleştirilmiş
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                if let range = Range(match.range(at: 1), in: text) {
                     let amountStr = String(text[range])
                     // Sayı temizle (TL formatı 1.000,00 -> 1000.00)
                     let cleanAmount = amountStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                     return Decimal(string: cleanAmount)
                }
            }
        }
        return nil
    }
    
    private func extractSupplier(text: String) -> String? {
        // Tedarikçi Regex ile çok zor, genellikle blok analizi daha iyi.
        // Basitçe VKN arayıp yanındaki kelimeleri alabiliriz ama riskli.
        // Şimdilik nil dönüp Coordinate Fallback'e bırakıyoruz.
        return nil
    }
    
    // Yardımcı: Tarih Parse
    private func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        // Olası formatlar
        let formats = ["dd-MM-yyyy", "dd.MM.yyyy", "dd/MM/yyyy"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) { return date }
        }
        return nil
    }
}

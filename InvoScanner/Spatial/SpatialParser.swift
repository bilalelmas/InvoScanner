import Foundation
import CoreGraphics

// MARK: - Spatial Parser

/// V5 Pipeline Orkestratörü
/// TextBlock → BlockClusterer → LayoutMap → BlockLabeler → Extraction
struct SpatialParser {
    
    // MARK: - Dependencies
    
    private let clusterer = BlockClusterer()
    private let labeler = BlockLabeler()
    private let amountVerifier = AmountToTextVerifier()
    
    // MARK: - Parsed Result
    
    struct ParsedInvoice {
        var ettn: String?
        var date: Date?
        var totalAmount: Decimal?
        var supplier: String?
        var buyer: String?
        var invoiceNumber: String?
        
        /// Tutar doğrulama sonucu
        var amountVerification: AmountToTextVerifier.VerificationResult?
        
        /// Layout haritası (debug için)
        var layoutMap: LayoutMap?
    }
    
    // MARK: - Main Parsing
    
    /// V5 Pipeline: Blokları kümeler, etiketler ve veri çıkarır
    /// - Parameter blocks: Ham TextBlock listesi (OCR veya PDF'den)
    /// - Returns: Ayrıştırılmış fatura verileri
    func parse(_ blocks: [TextBlock]) -> ParsedInvoice {
        // Adım 1: Spatial Kümeleme
        let semanticBlocks = clusterer.performClustering(blocks)
        
        // Adım 2: Semantik Etiketleme
        let labeledBlocks = labeler.performLabeling(semanticBlocks)
        
        // Adım 3: Layout Haritası Oluştur
        let layoutMap = LayoutMap.from(clusteredBlocks: labeledBlocks)
        
        // Debug: Haritayı yazdır
        #if DEBUG
        layoutMap.debugPrint()
        #endif
        
        // Adım 4: Etiket Bazlı Veri Çıkarımı
        var result = ParsedInvoice()
        result.layoutMap = layoutMap
        
        // Tüm metin (fallback için)
        let fullText = blocks.map { $0.text }.joined(separator: "\n")
        
        // ETTN (herhangi bir blokta olabilir)
        if let ettnBlock = layoutMap.allBlocks.first(where: { $0.label == .ettn }) {
            result.ettn = extractETTN(from: ettnBlock.text)
        }
        // Fallback: Tüm metinde ara
        if result.ettn == nil {
            result.ettn = extractETTN(from: fullText)
        }
        
        // Satıcı
        if let sellerBlock = layoutMap.leftBlock(withLabel: .seller) {
            result.supplier = extractSupplierName(from: sellerBlock.text)
        }
        // Fallback: VKN/TCKN ile tespit
        if result.supplier == nil {
            result.supplier = extractSupplierViaVKN(from: fullText)
        }
        
        // Alıcı
        if let buyerBlock = layoutMap.leftBlock(withLabel: .buyer) {
            result.buyer = extractBuyerName(from: buyerBlock.text)
        }
        
        // Meta (Fatura No, Tarih)
        if let metaBlock = layoutMap.rightBlock(withLabel: .meta) {
            let (invoiceNo, date) = extractMeta(from: metaBlock.text)
            result.invoiceNumber = invoiceNo
            result.date = date
        }
        // Fallback: Tüm metinden çıkar
        if result.invoiceNumber == nil || result.date == nil {
            let (invoiceNo, date) = extractMeta(from: fullText)
            result.invoiceNumber = result.invoiceNumber ?? invoiceNo
            result.date = result.date ?? date
        }
        
        // Toplamlar
        if let totalsBlock = layoutMap.rightBlock(withLabel: .totals) {
            result.totalAmount = extractTotalAmount(from: totalsBlock.text)
        }
        // Fallback: Tüm metinden çıkar
        if result.totalAmount == nil {
            result.totalAmount = extractTotalAmount(from: fullText)
        }
        
        // Yalnız... doğrulaması
        if let amount = result.totalAmount {
            result.amountVerification = amountVerifier.verify(
                numericAmount: amount,
                fullText: fullText
            )
        }
        
        return result
    }
    
    // MARK: - Extraction Helpers
    
    private func extractETTN(from text: String) -> String? {
        let pattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range) {
            return String(text[Range(match.range, in: text)!])
        }
        return nil
    }
    
    private func extractSupplierName(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // V5.1 FIX: Adres satırlarını atlama listesi
        let skipPrefixes = [
            "MAH", "MAHALLE", "CAD", "CADDE", "SOK", "SOKAK", "BULVAR",
            "NO:", "KAT:", "DAİRE", "DAIRE", "APT", "APARTMAN",
            "MERKEZ", "İLÇE", "ILCE", "İL:", "IL:",
            "VERGİ DAİRESİ", "VERGI DAIRESI", "VD:", "V.D.",
            "TEL:", "TELEFON", "FAX:", "E-POSTA", "EPOSTA", "E-MAIL"
        ]
        
        // V5.1 FIX: Tam kelime eşleşme için suffix'ler
        // "BAŞAK" içindeki "AŞ" eşleşmemeli
        let legalSuffixes = [" A.Ş", " AŞ", " LTD", " ŞTİ", " STI", " A.S.", " LTD.", ".Ş.", ".ş."]
        
        for line in lines {
            let upperLine = line.uppercased()
            
            // Adres satırını atla
            if isNoiseLine(upperLine, prefixes: skipPrefixes) { continue }
            
            // V5.1 FIX: Tam kelime suffix kontrolü
            // Suffix satırın sonunda veya boşluktan önce olmalı
            for suffix in legalSuffixes {
                if upperLine.hasSuffix(suffix.trimmingCharacters(in: .whitespaces)) ||
                   upperLine.contains(suffix) {
                    return line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Legal suffix yoksa ilk non-noise satırı döndür
        for line in lines {
            let upperLine = line.uppercased()
            if !isNoiseLine(upperLine, prefixes: skipPrefixes) && line.count > 3 {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Bir satırın "gürültü" (adres, iletişim vb.) olup olmadığını kontrol eder
    private func isNoiseLine(_ line: String, prefixes: [String]) -> Bool {
        for prefix in prefixes {
            if line.hasPrefix(prefix) || line.contains(prefix) {
                return true
            }
        }
        return false
    }
    
    /// VKN/TCKN satırının öncesindeki satırdan satıcı adını çıkarır
    /// Bu metod e-Arşiv faturalarında çok güvenilirdir
    private func extractSupplierViaVKN(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // VKN/TCKN satırını bul
        let vknKeywords = ["VKN", "TCKN", "VERGİ KİMLİK", "VERGI KIMLIK", "T.C. KİMLİK", "T.C. KIMLIK"]
        
        for (index, line) in lines.enumerated() {
            let upperLine = line.uppercased()
            
            for keyword in vknKeywords {
                if upperLine.contains(keyword) {
                    // VKN satırından önceki satır(lar)ı kontrol et
                    var supplierName: String?
                    
                    // Önceki satırları kontrol et (max 3 satır)
                    for offset in 1...min(3, index) {
                        let prevLine = lines[index - offset]
                        let upperPrevLine = prevLine.uppercased()
                        
                        // "SAYIN", adres kelimeleri vs atla
                        if upperPrevLine.contains("SAYIN") || 
                           upperPrevLine.contains("ALICI") ||
                           upperPrevLine.contains("ADRES") ||
                           upperPrevLine.hasPrefix("MAH") ||
                           upperPrevLine.hasPrefix("CAD") ||
                           upperPrevLine.hasPrefix("SOK") {
                            continue
                        }
                        
                        // Legal suffix varsa bu satıcı adı
                        let legalSuffixes = ["A.Ş", "AŞ", "LTD", "ŞTİ", "STI", "A.S.", "LTD."]
                        for suffix in legalSuffixes {
                            if upperPrevLine.contains(suffix) {
                                return prevLine
                            }
                        }
                        
                        // İlk anlamlı satırı al
                        if supplierName == nil && prevLine.count > 5 {
                            supplierName = prevLine
                        }
                    }
                    
                    return supplierName
                }
            }
        }
        
        return nil
    }
    
    private func extractBuyerName(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            // "SAYIN" sonrasını al
            if line.uppercased().contains("SAYIN") {
                if let range = line.uppercased().range(of: "SAYIN") {
                    let afterSayin = String(line[range.upperBound...])
                    return afterSayin.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractMeta(from text: String) -> (invoiceNo: String?, date: Date?) {
        let lines = text.components(separatedBy: .newlines)
        
        var invoiceNo: String?
        var date: Date?
        
        // Fatura No pattern
        // V5.1 FIX: [A-Z]{2,3} catches 2-letter prefixes like DM, EH, GIB
        // \d{7,} catches shorter invoice numbers
        let invoicePattern = try? NSRegularExpression(pattern: "[A-Z]{2,3}\\d{7,}", options: [])
        
        // Tarih pattern
        let datePattern = try? NSRegularExpression(pattern: "\\d{2}[./]\\d{2}[./]\\d{4}", options: [])
        
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            
            // Fatura No
            if invoiceNo == nil, let match = invoicePattern?.firstMatch(in: line, range: range) {
                invoiceNo = String(line[Range(match.range, in: line)!])
            }
            
            // Tarih
            if date == nil, let match = datePattern?.firstMatch(in: line, range: range) {
                let dateStr = String(line[Range(match.range, in: line)!])
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy"
                date = formatter.date(from: dateStr.replacingOccurrences(of: "/", with: "."))
            }
        }
        
        return (invoiceNo, date)
    }
    
    private func extractTotalAmount(from text: String) -> Decimal? {
        let lines = text.uppercased().components(separatedBy: .newlines)
        
        var maxAmount: Decimal = 0
        
        // Toplam satırlarını bul
        let keywords = ["GENEL TOPLAM", "ÖDENECEK TUTAR", "TOPLAM"]
        
        for line in lines {
            for keyword in keywords {
                if line.contains(keyword) {
                    if let amount = extractAmount(from: line), amount > maxAmount {
                        maxAmount = amount
                    }
                }
            }
        }
        
        return maxAmount > 0 ? maxAmount : nil
    }
    
    private func extractAmount(from text: String) -> Decimal? {
        // TR format: 1.234,56
        let pattern = "\\d{1,3}(?:\\.\\d{3})*,\\d{2}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range) {
            let amountStr = String(text[Range(match.range, in: text)!])
            let normalized = amountStr
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalized)
        }
        return nil
    }
}

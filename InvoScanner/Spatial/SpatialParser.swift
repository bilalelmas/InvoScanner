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
        
        // V5.2 FIX: Adres başlangıç anahtar kelimeleri - bunları görünce DUR
        let addressBreakWords = [
            "MAH", "MAHALLE", "CAD", "CADDE", "SOK", "SOKAK", "BULVAR",
            "NO:", "KAT:", "DAİRE", "DAIRE", "APT", "APARTMAN"
        ]
        
        // V5.2 Final Polish: Genişletilmiş noise/atlama listesi
        let noiseWords = [
            // Vergi bilgileri
            "VERGİ DAİRESİ", "VERGI DAIRESI", "VD:", "V.D.",
            // İletişim
            "TEL:", "TELEFON", "FAX:", "E-POSTA", "EPOSTA", "E-MAIL", "MAILTO:",
            // Konum
            "MERKEZ", "İLÇE", "ILCE", "İL:", "IL:",
            // Fatura başlıkları (yeni)
            "E-ARŞİV", "E-ARSIV", "E-FATURA", "E-İRSALİYE",
            "ARŞİV FATURA", "ARSIV FATURA",
            // Alıcı işaretleri
            "SAYIN", "SAYIN:", "ALICI", "ALICI:",
            "ADRES:", "ADRES :",
            // Diğer
            "MERSIS NO", "MERSİS NO"
        ]
        
        // V5.1 FIX: Tam kelime eşleşme için suffix'ler
        let legalSuffixes = [" A.Ş", " AŞ", " LTD", " ŞTİ", " STI", " A.S.", " LTD.", ".Ş.", ".ş."]
        
        var nameParts: [String] = []
        
        for line in lines {
            let upperLine = line.uppercased()
            
            // V5.2 FIX: Adres başladığı an DUR - sonraki satırları toplama
            var isAddressStart = false
            for word in addressBreakWords {
                if upperLine.hasPrefix(word) || upperLine.contains(" \(word)") {
                    isAddressStart = true
                    break
                }
            }
            if isAddressStart { break } // Döngüyü tamamen kır
            
            // V5.2 Final Polish: Noise satırını atla
            if isNoiseLine(upperLine, prefixes: noiseWords) { continue }
            
            // Legal suffix varsa bu kesin satıcı adı
            for suffix in legalSuffixes {
                if upperLine.hasSuffix(suffix.trimmingCharacters(in: .whitespaces)) ||
                   upperLine.contains(suffix) {
                    nameParts.append(line)
                    // V5.2 Final Polish: Suffix truncation - Legal suffix sonrasını kes
                    let result = nameParts.joined(separator: " ")
                    return truncateAfterLegalSuffix(result)
                }
            }
            
            // Potansiyel isim parçası olarak ekle
            if line.count > 2 {
                nameParts.append(line)
            }
        }
        
        // Birleştirilmiş ismi döndür
        if !nameParts.isEmpty {
            let result = nameParts.joined(separator: " ")
            return truncateAfterLegalSuffix(result)
        }
        
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// V5.2 Final Polish: Legal suffix sonrasındaki garbage'ı temizler
    /// Örn: "DSM GRUP TİCARET A.Ş. Mahalle Cad. No:5" -> "DSM GRUP TİCARET A.Ş."
    private func truncateAfterLegalSuffix(_ text: String) -> String {
        let suffixes = ["A.Ş.", "AŞ.", "A.Ş", "LTD.ŞTİ.", "LTD. ŞTİ.", "LTD.ŞTİ", "LTD ŞTİ", "LTD.", "ŞTİ.", "STI."]
        let upperText = text.uppercased()
        
        for suffix in suffixes {
            if let range = upperText.range(of: suffix) {
                let endIndex = range.upperBound
                let originalEndIndex = text.index(text.startIndex, offsetBy: upperText.distance(from: upperText.startIndex, to: endIndex))
                return String(text[..<originalEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        // V5.2 FIX: E-Arşiv öncelikli fatura no arama
        // Öncelik 1: E-Arşiv standardı [A-Z]{3}202[0-5]\d{9}
        let eArsivPattern = try? NSRegularExpression(pattern: "[A-Z]{3}202[0-5]\\d{9}", options: [])
        // Öncelik 2: Genel format [A-Z0-9]{2,3}\d{7,13}
        let generalPattern = try? NSRegularExpression(pattern: "[A-Z0-9]{2,3}\\d{7,13}", options: [])
        
        // Tarih pattern
        let datePattern = try? NSRegularExpression(pattern: "\\d{2}[./-]\\d{2}[./-]\\d{4}", options: [])
        
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            
            // Fatura No - Önce E-Arşiv formatını dene
            if invoiceNo == nil {
                if let match = eArsivPattern?.firstMatch(in: line, range: range) {
                    let candidate = String(line[Range(match.range, in: line)!])
                    if !isPhoneOrTCKN(candidate) {
                        invoiceNo = candidate
                    }
                }
            }
            
            // Fallback: Genel format
            if invoiceNo == nil {
                if let match = generalPattern?.firstMatch(in: line, range: range) {
                    let candidate = String(line[Range(match.range, in: line)!])
                    if !isPhoneOrTCKN(candidate) {
                        invoiceNo = candidate
                    }
                }
            }
            
            // Tarih
            if date == nil, let match = datePattern?.firstMatch(in: line, range: range) {
                var dateStr = String(line[Range(match.range, in: line)!])
                
                // V5.2 FIX: Saat bilgisini temizle (HH:MM:SS)
                dateStr = dateStr.replacingOccurrences(of: "/", with: ".")
                dateStr = dateStr.replacingOccurrences(of: "-", with: ".")
                
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy"
                date = formatter.date(from: dateStr)
            }
        }
        
        return (invoiceNo, date)
    }
    
    /// V5.2 FIX: Telefon/TCKN numarası mı kontrol et
    /// 10-11 haneli salt rakam = muhtemelen telefon veya TCKN
    private func isPhoneOrTCKN(_ value: String) -> Bool {
        // Sadece rakamlardan oluşuyor mu?
        let digitsOnly = value.filter { $0.isNumber }
        
        // Değerin tamamı rakamsa ve 10-11 hane arasıysa
        if value == digitsOnly && (digitsOnly.count == 10 || digitsOnly.count == 11) {
            return true
        }
        
        // 0 ile başlıyorsa muhtemelen telefon
        if value.hasPrefix("0") && digitsOnly.count >= 10 {
            return true
        }
        
        return false
    }
    
    private func extractTotalAmount(from text: String) -> Decimal? {
        let lines = text.uppercased().components(separatedBy: .newlines)
        
        // V5.2 Final Polish: Öncelik bazlı anahtar kelimeler
        // Yüksek öncelikli kelimeler düşük öncelikliden daha güvenilir
        let priorityKeywords: [(keyword: String, priority: Int)] = [
            ("ÖDENECEK TUTAR", 100),
            ("ODENECEK TUTAR", 100),
            ("GENEL TOPLAM", 90),
            ("VERGİLER DAHİL TOPLAM", 85),
            ("VERGILER DAHIL TOPLAM", 85),
            ("VERGİLİ MAL BEDELİ", 80),
            ("VERGILI MAL BEDELI", 80),
            ("ÖDENECEK", 75),
            ("ODENECEK", 75),
            ("TOPLAM TUTAR", 60),
            ("TOPLAM", 50)  // En düşük öncelik
        ]
        
        // Aday tutarları (tutar, öncelik) olarak topla
        var candidates: [(amount: Decimal, priority: Int)] = []
        
        for line in lines {
            for (keyword, priority) in priorityKeywords {
                if line.contains(keyword) {
                    if let amount = extractAmount(from: line), amount > 0 {
                        candidates.append((amount, priority))
                    }
                    break // Bir satırda bir keyword yeterli
                }
            }
        }
        
        // En yüksek öncelikli tutarı seç
        // Aynı öncelikte birden fazla varsa en büyük tutarı al
        if let best = candidates.sorted(by: { 
            if $0.priority != $1.priority {
                return $0.priority > $1.priority // Öncelik yüksek olan önce
            }
            return $0.amount > $1.amount // Aynı öncelikte büyük tutar
        }).first {
            return best.amount
        }
        
        return nil
    }
    
    private func extractAmount(from text: String) -> Decimal? {
        // V5.2 FIX: Esnek tutar regex - OCR varyasyonlarını kapsar
        // Standart TR: 1.234,56
        // OCR hataları: 1 234,56 veya 1.234.56 veya 1234,56
        
        // Önce standart TR formatını dene
        let standardPattern = "\\d{1,3}(?:[.\\s]\\d{3})*[,]\\d{2}"
        if let result = tryExtractAmount(from: text, pattern: standardPattern) {
            return result
        }
        
        // Fallback: Basit virgüllü format (1234,56)
        let simplePattern = "\\d+[,]\\d{2}"
        if let result = tryExtractAmount(from: text, pattern: simplePattern) {
            return result
        }
        
        // Fallback: Noktalı format (1234.56 - yabancı format veya OCR hatası)
        let dotPattern = "\\d{1,3}(?:\\s\\d{3})*\\.\\d{2}$"
        return tryExtractAmount(from: text, pattern: dotPattern, useDot: true)
    }
    
    /// Pattern ile tutar çıkarma helper
    private func tryExtractAmount(from text: String, pattern: String, useDot: Bool = false) -> Decimal? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range) {
            var amountStr = String(text[Range(match.range, in: text)!])
            
            // Normalize: Boşlukları temizle
            amountStr = amountStr.replacingOccurrences(of: " ", with: "")
            
            if useDot {
                // Nokta ondalık ayırıcı
                amountStr = amountStr.replacingOccurrences(of: ",", with: "")
            } else {
                // Virgül ondalık ayırıcı (TR standart)
                amountStr = amountStr
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            }
            
            return Decimal(string: amountStr)
        }
        return nil
    }
}

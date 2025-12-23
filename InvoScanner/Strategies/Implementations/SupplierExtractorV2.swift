import Foundation

/// V3 Satıcı Tespit Algoritması (Production-Grade)
/// Senior İlke: Yapısal tespit, coğrafi sözlük YOK
struct SupplierExtractorV2 {
    
    // MARK: - Constants (Yapısal - Coğrafi liste YOK)
    
    // Vergi bloğu tetikleyicileri
    private let taxIndicators = ["VKN", "VERGI DAIRESI", "TCKN", "VERGI NO", "TC KIMLIK", "VERGI KIMLIK"]
    
    // Yapısal adres belirteçleri (Coğrafi isim DEĞİL, yapısal sinyal)
    private let addressMarkers = [
        "MAH", "MAHALLESI", "MAHALLE", "MH.",
        "SOKAK", "SOK.", "SOK ", "SK.", "SK ",
        "CADDE", "CAD.", "CAD ",
        "NO:", "APT", "DAIRE", "KAT:",
        "E-POSTA:", "E-POSTA", "TEL:", "FAX:", "WEB SITESI:"
    ]
    
    // Durma kelimeleri
    private let stopPatterns = ["E-ARSIV", "FATURA", "SAYIN", "TESLIMAT", "ALICI", "MUSTERI"]
    
    // Kurumsal şirket kalıpları (Yapısal)
    private let corporateKeywords = ["A.S.", "A.S", "LTD.", "LTD", "LIMITED", "ANONIM", "SIRKETI", "TIC."]
    
    // Kargo/Aracı firmalar (Satıcı olamaz)
    private let excludedCompanies = [
        "POSTA VE TELGRAF", "PTT", "ARAS KARGO", "YURTICI KARGO", "MNG KARGO", 
        "SURAT KARGO", "UPS", "DHL", "HEPSIJET", "D FAST"
    ]
    
    // MARK: - Main Extraction
    
    func extract(from text: String) -> String? {
        // TCKN veya VKN'yi belirle
        let hasTCKN = detectTCKN(in: text)
        let hasVKN = detectVKN(in: text)
        
        print("SupplierV2.1: TCKN=\(hasTCKN), VKN=\(hasVKN)")
        
        // KURAL 3: TCKN varsa şahıs öncelikli (V2.2: TCKN+VKN durumunda da dene)
        if hasTCKN {
            if let individual = extractIndividualSeller(from: text) {
                print("SupplierV2.1: Şahıs satıcı bulundu: \(individual)")
                return individual
            }
        }
        
        // Kurumsal satıcı arama
        if let corporate = extractCorporateSeller(from: text) {
            print("SupplierV2.1: Kurumsal satıcı bulundu: \(corporate)")
            return corporate
        }
        
        // Fallback: Satır tarama
        if let fallback = extractWithLineScanning(from: text) {
            print("SupplierV2.1: Satır taraması ile bulundu: \(fallback)")
            return fallback
        }
        
        print("SupplierV2.1: Satıcı bulunamadı.")
        return nil
    }
    
    // MARK: - TCKN/VKN Detection
    
    private func detectTCKN(in text: String) -> Bool {
        // TCKN = 11 haneli sayı
        let pattern = "TCKN[:\\s]*([0-9]{11})"
        if let regex = try? NSRegularExpression(pattern: pattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }
        return false
    }
    
    private func detectVKN(in text: String) -> Bool {
        // VKN = 10 haneli sayı
        let pattern = "VKN[:\\s]*([0-9]{10})"
        if let regex = try? NSRegularExpression(pattern: pattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }
        return false
    }
    
    // MARK: - Individual Seller (Şahıs) - KURAL 3
    
    private func extractIndividualSeller(from text: String) -> String? {
        // TCKN'nin pozisyonunu bul
        guard let tcknRange = text.range(of: "TCKN") else { return nil }
        
        // TCKN'den önceki metni al
        let beforeTCKN = String(text[..<tcknRange.lowerBound])
        
        // Son stop pattern'i bul
        var lastStopIndex = beforeTCKN.startIndex
        for stop in stopPatterns {
            if let range = beforeTCKN.range(of: stop, options: .backwards) {
                if range.upperBound > lastStopIndex {
                    lastStopIndex = range.upperBound
                }
            }
        }
        
        // Stop ile TCKN arası
        let candidate = String(beforeTCKN[lastStopIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Kurumsal keyword varsa bu şahıs değil, atla
        for corp in corporateKeywords {
            if candidate.contains(corp) { return nil }
        }
        
        // Kargo/Aracı firma kontrolü
        for excluded in excludedCompanies {
            if candidate.contains(excluded) { return nil }
        }
        
        // 2-5 kelimelik basit isim mi?
        let words = candidate.split(separator: " ").filter { !$0.isEmpty }
        if words.count >= 2 && words.count <= 5 {
            let digitRatio = Double(candidate.filter { $0.isNumber }.count) / Double(max(candidate.count, 1))
            if digitRatio < 0.10 {
                return cleanSupplierName(candidate)
            }
        }
        
        return nil
    }
    
    // MARK: - Corporate Seller (Kurumsal)
    
    private func extractCorporateSeller(from text: String) -> String? {
        // Kurumsal pattern: "XXXX A.S." veya "XXXX LTD."
        let pattern = "([A-Z][A-Z\\s\\.]{3,}(?:A\\.S\\.|LTD\\.|LIMITED|ANONIM|SIRKETI)[A-Z\\s\\.]*?)(?=\\s*(?:ADRES|TEL:|WEB|E-POSTA|MAHALLE|MAH|CAD|SOK|NO:|VERGI|VKN|TCKN|[0-9]{5,}))"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        // Tüm eşleşmeleri bul
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let rawName = String(text[range])
                
                // Kargo/Aracı firma kontrolü
                var isExcluded = false
                for excluded in excludedCompanies {
                    if rawName.contains(excluded) {
                        isExcluded = true
                        break
                    }
                }
                
                if !isExcluded {
                    return cleanSupplierName(rawName)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Line Scanning (Fallback) - KURAL 1 & 2
    
    private func extractWithLineScanning(from text: String) -> String? {
        // Metni yapay satırlara böl
        var processedText = text
        var lineBreakKeywords = ["VERGI DAIRESI", "SAYIN", "E-ARSIV", "ADRES:", "TEL:", "WEB SITESI:", "E-POSTA:", "VKN:", "TCKN:"]
        
        // V3: Adres belirteçleri ile de böl (PDFKit birleştirmesine karşı)
        lineBreakKeywords.append(contentsOf: ["MAHALLE", "MAH.", "CADDE", "CAD.", "SOKAK", "SOK.", "NO:"])
        
        for keyword in lineBreakKeywords {
            processedText = processedText.replacingOccurrences(of: keyword, with: "\n\(keyword)")
        }
        
        let lines = processedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Vergi satırını bul
        guard let taxLineIndex = lines.firstIndex(where: { line in
            taxIndicators.contains { line.contains($0) }
        }) else { return nil }
        
        // Yukarı tara
        for i in stride(from: taxLineIndex - 1, through: 0, by: -1) {
            let line = lines[i]
            
            // Stop pattern kontrolü
            if stopPatterns.contains(where: { line.contains($0) }) { break }
            
            // KURAL 2: MAH içeriyorsa bir üst satırı al
            if containsAddressKeyword(line) {
                // Bir üst satır var mı?
                if i > 0 {
                    let upperLine = lines[i - 1]
                    if !containsAddressKeyword(upperLine) && isValidSupplierLine(upperLine) {
                        print("SupplierV2.1: MAH kuralı - üst satır alındı: \(upperLine)")
                        return cleanSupplierName(upperLine)
                    }
                }
                continue // Bu satırı atla
            }
            
            // Geçerli satıcı satırı mı?
            if isValidSupplierLine(line) {
                return cleanSupplierName(line)
            }
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    // V3: Yapısal adres tespiti
    private func containsAddressKeyword(_ line: String) -> Bool {
        for marker in addressMarkers {
            if line.contains(marker) { return true }
        }
        return false
    }
    
    private func isValidSupplierLine(_ line: String) -> Bool {
        let words = line.split(separator: " ")
        guard words.count >= 2 else { return false }
        
        // Kargo/Aracı firma kontrolü
        for excluded in excludedCompanies {
            if line.contains(excluded) { return false }
        }
        
        let digitRatio = Double(line.filter { $0.isNumber }.count) / Double(max(line.count, 1))
        return digitRatio < 0.20
    }
    
    // MARK: - Garbage Patterns (Yapısal, liste değil)
    private let garbagePatterns = [
        "TEL:", "FAX:", "VKN/", "V.D.", "VERGI DAIRESI:", "E-POSTA:", "@", ".COM", 
        "TCKN:", "TICARETSICILNO:", "MERSISNO:", "WEB SITESI:"
    ]
    
    // MARK: - V3: Yapısal Temizlik (Coğrafi sözlük YOK)
    private func cleanSupplierName(_ raw: String) -> String? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Başındaki sayı/noktalama temizle
        cleaned = cleaned.replacingOccurrences(of: "^[0-9\\-\\.\\*\\:]+\\s*", with: "", options: .regularExpression)
        
        // Yapısal adres parçalarını temizle (Coğrafi isim DEĞİL)
        let structuralPatterns = [
            "\\s+MAHALLE.*", "\\s+MAH\\..*", "\\s+MAH\\s.*", "\\s+MH\\..*", "\\s+MH\\s.*",
            "\\s+CADDE.*", "\\s+CAD\\..*", "\\s+CAD\\s.*",
            "\\s+SOKAK.*", "\\s+SOK\\..*", "\\s+SOK\\s.*", "\\s+SOK$",
            "\\s+SK\\..*", "\\s+SK\\s.*", "\\s+SK$",
            "\\s+NO:.*", "\\s+APT.*", "\\s+KAT:.*", "\\s+DAIRE.*",
            "\\s+\\d+/.*", "\\s+\\d+\\s*$"  // Sondaki sayılar
        ]
        for pattern in structuralPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        // Kalite kontrolü: isQualitySupplierName
        guard isQualitySupplierName(cleaned) else {
            return nil
        }
        
        return cleaned
    }
    
    // MARK: - V3: Quality Score (Yapısal değerlendirme)
    private func isQualitySupplierName(_ text: String) -> Bool {
        // Uzunluk kontrolü
        guard text.count >= 5 && text.count <= 120 else {
            print("SupplierV3: Uzunluk hatası (\(text.count)): \(text)")
            return false
        }
        
        // Kelime sayısı
        let words = text.split(separator: " ").filter { !$0.isEmpty }
        guard words.count >= 2 && words.count <= 12 else {
            print("SupplierV3: Kelime sayısı hatası (\(words.count)): \(text)")
            return false
        }
        
        // Rakam oranı < %15
        let digitCount = text.filter { $0.isNumber }.count
        let digitRatio = Double(digitCount) / Double(text.count)
        if digitRatio > 0.15 {
            print("SupplierV3: Yüksek rakam oranı (\(String(format: "%.2f", digitRatio))): \(text)")
            return false
        }
        
        // Noktalama oranı < %25
        let punctCount = text.filter { $0.isPunctuation }.count
        let punctRatio = Double(punctCount) / Double(text.count)
        if punctRatio > 0.25 {
            print("SupplierV3: Yüksek noktalama oranı (\(String(format: "%.2f", punctRatio))): \(text)")
            return false
        }
        
        // Garbage pattern kontrolü
        for garbage in garbagePatterns {
            if text.contains(garbage) {
                print("SupplierV3: Garbage tespit edildi: \(text)")
                return false
            }
        }
        
        return true
    }
}

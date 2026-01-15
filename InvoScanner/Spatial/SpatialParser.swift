import Foundation
import CoreGraphics

// MARK: - Spatial Parser

/// Fatura ayrıştırma pipeline'ı
/// TextBlock → Kümeleme → Etiketleme → Veri Çıkarımı
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
    
    // MARK: - Ana Ayrıştırma
    
    /// Blokları kümeler, etiketler ve veri çıkarır
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
        
        // ETTN Küresel Arama (Tüm metinde ara)
        result.ettn = extractETTN(from: fullText)
        
        // Fallback 1: Eğer tüm metinde bulunamadıysa, etiketli bloklarda ara
        if result.ettn == nil, let ettnBlock = layoutMap.allBlocks.first(where: { $0.label == .ettn }) {
            result.ettn = extractETTN(from: ettnBlock.text)
        }
        
        // Fallback 2: Unknown bloklarda ara (ETTN bazen unknown olarak etiketlenebilir)
        if result.ettn == nil {
            for block in layoutMap.allBlocks where block.label == .unknown {
                if let ettn = extractETTN(from: block.text) {
                    result.ettn = ettn
                    break
                }
            }
        }
        
        // Satıcı
        if let sellerBlock = layoutMap.leftBlock(withLabel: .seller) {
            let extracted = extractSupplierName(from: sellerBlock.text)
            if let name = extracted, isValidSupplierName(name) {
                result.supplier = name
            }
        }
        // Fallback 1: VKN/TCKN ile tespit
        if result.supplier == nil {
            let extracted = extractSupplierViaVKN(from: fullText)
            if let name = extracted, isValidSupplierName(name) {
                result.supplier = name
            }
        }
        // Fallback 2: Şahıs faturaları için - buyer bloğunun ilk satırı
        if result.supplier == nil {
            if let buyerBlock = layoutMap.leftBlock(withLabel: .buyer) {
                result.supplier = extractFirstMeaningfulLine(from: buyerBlock.text)
            }
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
        // PDF Ligature Temizliği ('ff' -> 'ff')
        let cleanText = text
            .replacingOccurrences(of: "ﬀ", with: "ff")  // Ligature: ff
            .replacingOccurrences(of: "ﬁ", with: "fi")  // Ligature: fi
            .replacingOccurrences(of: "ﬂ", with: "fl")  // Ligature: fl
            .replacingOccurrences(of: "ﬃ", with: "ffi") // Ligature: ffi
            .replacingOccurrences(of: "ﬄ", with: "ffl") // Ligature: ffl
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased() // Regex için hepsini büyük harf yap
        
        // Önce ETTN etiketli pattern'i dene
        let labeledPattern = "(?:ETTN|ETTV)[:]?([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})"
        if let regex = try? NSRegularExpression(pattern: labeledPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText)),
           let captureRange = Range(match.range(at: 1), in: cleanText) {
            return String(cleanText[captureRange])
        }
        
        // Fallback: Herhangi bir UUID pattern'i (ETTN etiketi olmadan)
        let uuidPattern = "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
        guard let regex = try? NSRegularExpression(pattern: uuidPattern) else { return nil }
        
        let range = NSRange(cleanText.startIndex..., in: cleanText)
        if let match = regex.firstMatch(in: cleanText, range: range) {
            return String(cleanText[Range(match.range, in: cleanText)!])
        }
        return nil
    }
    
    /// Satıcı ismini ayıklar ve temizler
    private func extractSupplierName(from text: String) -> String? {
        // 1. Satır Satır Analiz (Line-by-Line Analysis)
        let lines = text.components(separatedBy: .newlines)
            .map { cleanSellerLabel($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !isLabelOnlyLine($0) }
        
        // İsmi bitiren "Terminatör" kelimeler
        let terminators = [
            // Adres etiketleri
            "ADRES", "ADRES:",
            // Mahalle/Cadde/Sokak
            "MAH.", "MAHALLE", "MAHALLESİ", "MAHALLESI",
            "CAD.", "CADDE", "CADDESİ", "CADDESI",
            "SOK.", "SOKAK", "SOKAĞI", "SOKAGI",
            "BULVAR", "MEYDAN",
            // Yapı bilgileri
            "NO:", "KAT:", "DAİRE", "DAIRE", "APT", "BLOK", "PK:",
            // İletişim
            "TEL:", "VKN:", "TCKN:", "VERGİ", "VERGI", "WEB", "E-POSTA",
            // İl isimleri (adres başlangıcı)
            "İSTANBUL", "ISTANBUL", "ANKARA", "İZMİR", "IZMIR", "KOCAELİ", "KOCAELI",
            "BURSA", "ANTALYA", "ADANA", "KONYA", "GAZİANTEP", "GAZIANTEP",
            // Lojistik kelimeleri (asla isimde olmamalı)
            "TAŞIYAN", "TASIYAN", "KARGO", "LOJİSTİK", "LOJISTIK", "NAKLİYE", "NAKLIYE"
        ]
        
        // Gürültü kelimeleri
        var noiseWords = [
            "VERGİ DAİRESİ", "VERGI DAIRESI", "VD:", "V.D.",
            "SAYIN", "SAYIN:", "ALICI", "ALICI:",
            "E-ARŞİV", "E-ARSIV", "E-FATURA",
            "MERSIS NO", "MERSİS NO"
        ]
        noiseWords.append(contentsOf: ExtractionConstants.sloganNoise)
        
        var nameParts: [String] = []
        
        for line in lines {
            let upperLine = line.uppercased(with: Locale(identifier: "tr_TR"))
            
            // Posta kodu kontrolü (beş haneli sayı ile başlayan satır = adres)
            if upperLine.range(of: #"^\d{5}\b"#, options: .regularExpression) != nil {
                break
            }
            
            // Satır tamamen gürültü mü?
            if isNoiseLine(upperLine, prefixes: noiseWords) { continue }
            
            // Satır İÇİNDE terminatör var mı?
            var cleanLine = line
            var foundTerminator = false
            
            for term in terminators {
                // Boşlukla başlayan kelimeyi ara (kelime sınırı)
                if let range = upperLine.range(of: " " + term) {
                    // Terminatörden ÖNCESİNİ al
                    let cutIndex = line.index(line.startIndex, offsetBy: upperLine.distance(from: upperLine.startIndex, to: range.lowerBound))
                    cleanLine = String(line[..<cutIndex]).trimmingCharacters(in: .whitespaces)
                    foundTerminator = true
                    break
                }
                // Satır başında da kontrol et
                if upperLine.hasPrefix(term) {
                    cleanLine = ""
                    foundTerminator = true
                    break
                }
            }
            
            // Temizlenmiş satır boşsa
            if cleanLine.isEmpty {
                if foundTerminator { break }
                continue
            }
            
            nameParts.append(cleanLine)
            
            // Terminatör bulunduysa döngüden çık
            if foundTerminator { break }
        }
        
        // 2. Birleştirilmiş ismi al
        let fullName = nameParts.joined(separator: " ")
        
        // 3. Kurumsal Sonek Kontrolü (Hard Cut)
        if !fullName.isEmpty {
            return cleanLeadingNumbers(cleanSellerLabel(applyHardSuffixCut(fullName)))
        }
        
        // 4. Şahıs ismi fallback (2-4 kelime, adres/kargo değil)
        if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) {
            let words = firstLine.split(separator: " ")
            if words.count >= 2 && words.count <= 4 {
                let upperFirst = firstLine.uppercased()
                if !upperFirst.contains("MAH") && !upperFirst.contains("CAD") &&
                   !upperFirst.contains("SOK") && !upperFirst.contains("NO:") &&
                   !upperFirst.contains("KARGO") && !upperFirst.contains("TAŞIYAN") &&
                   !upperFirst.contains("GÖNDERİ") {
                    return cleanLeadingNumbers(cleanSellerLabel(firstLine))
                }
            }
            return cleanLeadingNumbers(cleanSellerLabel(firstLine))
        }
        
        return nil
    }
    
    /// Sonek sonrası kesin kesim (Hard Cut)
    private func applyHardSuffixCut(_ text: String) -> String {
        let upperText = text.uppercased(with: Locale(identifier: "tr_TR"))
        
        for suffix in ExtractionConstants.legalSuffixesOrdered {
            if let range = upperText.range(of: suffix) {
                // Sonekin bittiği yer
                let endIndex = range.upperBound
                let originalEndIndex = text.index(text.startIndex, offsetBy: upperText.distance(from: upperText.startIndex, to: endIndex))
                
                // Soneke kadar al, gerisini çöpe at
                return String(text[..<originalEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
    
    /// Satıcı etiketi öneklerini temizler
    /// Örn: "Satıcı (Merkez): Moonlıfe Mobilya..." → "Moonlıfe Mobilya..."
    private func cleanSellerLabel(_ text: String) -> String {
        var cleaned = text
        
        // Satıcı etiketlerini çıkar (Türkçe karakterlerle)
        let sellerLabelPatterns = [
            // "Satıcı (Merkez):" veya "SATICI (MERKEZ):" - Türkçe ı/İ karakterleri dahil
            #"^[Ss][Aa][Tt][ıİIi][Cc][ıİIi]\s*\([^)]*\)\s*:?\s*"#,
            #"^[Ss][Aa][Tt][ıİIi][Cc][ıİIi]\s*:?\s*"#,        // "Satıcı:" veya "SATICI:"
            #"^[Ss][Aa][Tt][ıİIi][Cc][ıİIi][Nn][ıİIi][Nn]\s*:?\s*"#  // "Satıcının:"
        ]
        
        for pattern in sellerLabelPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        
        // e-Arşiv Fatura başlıklarını temizle
        let arsivPatterns = [
            #"^e-?\s*[Aa]\s*rş\s*[iı]?v\s+[Ff]atura\s*"#,
            #"^E-?ARŞİV\s*FATURA\s*"#,
            #"^e-?arsiv\s*fatura\s*"#
        ]
        
        for pattern in arsivPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // "Etiket:" pattern'lerini temizle (Vergi Dairesi:, TCKN:, vb.)
        // Sadece baştan değil, genel temizlik
        let labelPrefixPatterns = [
            #"^Vergi\s*Dairesi\s*:.*"#,
            #"^VD\s*:.*"#,
            #"^V\.D\.\s*:.*"#,
            #"^TCKN\s*:.*"#,
            #"^VKN\s*:.*"#,
            #"^Web\s*Sitesi\s*:.*"#
        ]
        
        for pattern in labelPrefixPatterns {
            if cleaned.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                // Eğer sonuç sadece etiket satırıysa, bu satıcı adı değil
                return ""
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    /// Bloktan ilk anlamlı satırı al (şahıs faturaları için)
    /// Etiket satırlarını (XXX:) atlar, ilk gerçek ismi alır
    private func extractFirstMeaningfulLine(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Etiket satırı patern'leri (atlaması gerekenler)
        let labelPatterns = [
            #"^Vergi\s*Dairesi\s*:"#,
            #"^VD\s*:"#,
            #"^V\.D\.\s*:"#,
            #"^TCKN\s*:"#,
            #"^VKN\s*:"#,
            #"^Tel\s*:"#,
            #"^Telefon\s*:"#,
            #"^E-?[Pp]osta\s*:"#,
            #"^Web\s*Sitesi\s*:"#,
            #"^Adres\s*:"#,
            #"^SAYIN"#,
            #"^ALICI"#
        ]
        
        for line in lines {
            let isLabelLine = labelPatterns.contains { pattern in
                line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
            
            if !isLabelLine && line.count > 3 {
                // İlk anlamlı satır - bu isim
                return cleanLeadingNumbers(line)
            }
        }
        
        return nil
    }
    
    /// Satıcı adı başındaki VKN/telefon numarasını temizler
    /// Örn: "9795582114 DSM Grup Danışmanlık..." → "DSM Grup Danışmanlık..."
    private func cleanLeadingNumbers(_ text: String) -> String {
        // 9-11 haneli sayı + boşluk ile başlıyorsa temizle
        let cleaned = text.replacingOccurrences(
            of: #"^\d{9,11}\s+"#,
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    /// : Satıcı adı geçerliliğini kontrol eder
    /// Geçersiz sonuçlar fallback'i tetikler
    private func isValidSupplierName(_ name: String) -> Bool {
        // Minimum uzunluk
        guard name.count >= 4 else { return false }
        
        // Bilinen geçersiz pattern'ler
        let invalidPatterns = [
            #"^Vergi\s*Dairesi"#,
            #"^VD\s*:"#,
            #"^V\.D\.\s*:"#,
            #"^[Ss][Aa][Tt][ıİIi][Cc][ıİIi]\s*\("#,  // "Satıcı (" etiket kaldı
            #"^TCKN\s*:"#,
            #"^VKN\s*:"#,
            #"^Tel\s*:"#,
            #"^\d{9,11}$"#  // Sadece sayı
        ]
        
        for pattern in invalidPatterns {
            if name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return false
            }
        }
        return true
    }
    
    /// : Sadece etiket içeren satırları tespit eder (filtrele)
    private func isLabelOnlyLine(_ line: String) -> Bool {
        let labelPatterns = [
            #"^Vergi\s*Dairesi\s*:"#,
            #"^VD\s*:"#,
            #"^V\.D\.\s*:"#,
            #"^TCKN\s*:"#,
            #"^VKN\s*:"#,
            #"^Tel\s*:"#,
            #"^Telefon\s*:"#,
            #"^FAX\s*:"#,
            #"^E-?[Pp]osta\s*:"#,
            #"^Web\s*Sitesi\s*:"#,
            #"^Adres\s*:"#,
            #"^MERSIS\s*(NO)?\s*:"#
        ]
        
        return labelPatterns.contains { pattern in
            line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
    
    /// Legal suffix sonrasındaki her şeyi (adres başlangıcı dahil) kesin olarak temizler
    /// Örn: "AS KARAKIZ... LİMİTED ŞİRKETİ YÜRÜKSELİM" -> "AS KARAKIZ... LİMİTED ŞİRKETİ"
    /// Örn: "SALVANINI... LİMİTED ŞİRKETİ ÖMERLİ" -> "SALVANINI... LİMİTED ŞİRKETİ"
    private func truncateAfterLegalSuffix(_ text: String) -> String {
        // Türkçe locale ile büyük harf dönüşümü (ı→I, i→İ)
        let upperText = text.uppercased(with: Locale(identifier: "tr_TR"))
        
        // En uzun eşleşmeyi bulmak için sıralı liste
        for suffix in ExtractionConstants.legalSuffixesOrdered {
            if let range = upperText.range(of: suffix) {
                // Sonekin bittiği yeri bul
                let endIndex = range.upperBound
                
                // Orijinal metinde bu indexe karşılık gelen yer
                let originalEndIndex = text.index(text.startIndex, offsetBy: upperText.distance(from: upperText.startIndex, to: endIndex))
                
                // Kesin kesim - sadece soneke kadar olan kısmı al
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
        
        // E-Arşiv öncelikli fatura no arama
        // Öncelik 1: E-Arşiv standardı [A-Z]{3}202[0-5]\d{9}
        let eArsivPattern = try? NSRegularExpression(pattern: "[A-Z]{3}202[0-5]\\d{9}", options: [])
        // Öncelik 2: Genel format [A-Z0-9]{2,3}\d{7,13}
        let generalPattern = try? NSRegularExpression(pattern: "[A-Z0-9]{2,3}\\d{7,13}", options: [])
        
        // Tarih pattern - DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY formatları
        let datePattern = try? NSRegularExpression(pattern: #"\d{2}\s*[-./]\s*\d{2}\s*[-./]\s*\d{4}"#, options: [])
        
        // Önce etiketli tarih ara (daha güvenilir)
        // (?:Fatura|Düzenlenme)\s*Tarihi\s*[:]?\s*(\d{2}[./-]\d{2}[./-]\d{4})
        let labeledDatePattern = #"(?:Fatura|Düzenlenme|FATURA|DÜZENLENME)\s*(?:Tarihi|TARİHİ|TARIHI)\s*[:]?\s*(\d{2}\s*[-./]\s*\d{2}\s*[-./]\s*\d{4})"#
        if let regex = try? NSRegularExpression(pattern: labeledDatePattern, options: .caseInsensitive) {
            let fullRange = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: fullRange),
               let captureRange = Range(match.range(at: 1), in: text) {
                var dateStr = String(text[captureRange])
                date = parseDate(dateStr)
            }
        }
        
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            
            // Fatura No - Önce E-Arşiv formatını dene
            if invoiceNo == nil {
                if let match = eArsivPattern?.firstMatch(in: line, range: range) {
                    let candidate = String(line[Range(match.range, in: line)!])
                    // Gelişmiş validasyon
                    if isValidInvoiceNumber(candidate) {
                        invoiceNo = candidate
                    }
                }
            }
            
            // Fallback: Genel format
            if invoiceNo == nil {
                if let match = generalPattern?.firstMatch(in: line, range: range) {
                    let candidate = String(line[Range(match.range, in: line)!])
                    // Gelişmiş validasyon
                    if isValidInvoiceNumber(candidate) {
                        invoiceNo = candidate
                    }
                }
            }
            
            // Fallback tarih - etiket bulunamadıysa herhangi bir tarih pattern'i
            if date == nil, let match = datePattern?.firstMatch(in: line, range: range) {
                let dateStr = String(line[Range(match.range, in: line)!])
                date = parseDate(dateStr)
            }
        }
        
        return (invoiceNo, date)
    }
    
    /// Tarih string'ini Date nesnesine çevirir
    /// Desteklenen formatlar: DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY
    private func parseDate(_ rawDateStr: String) -> Date? {
        var dateStr = rawDateStr
        
        // Boşlukları temizle ("20- 08- 2024" → "20-08-2024")
        dateStr = dateStr.replacingOccurrences(of: " ", with: "")
        
        // Saat bilgisini temizle ("10.06.2024-16:06:26" → "10.06.2024")
        dateStr = dateStr.replacingOccurrences(
            of: #"-\d{2}:\d{2}:\d{2}"#,
            with: "",
            options: .regularExpression
        )
        dateStr = dateStr.replacingOccurrences(
            of: #"\s\d{2}:\d{2}:\d{2}"#,
            with: "",
            options: .regularExpression
        )
        
        // Karakter normalizasyonu
        dateStr = dateStr.replacingOccurrences(of: "/", with: ".")
        dateStr = dateStr.replacingOccurrences(of: "-", with: ".")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: dateStr)
    }
    
    /// -5.3 FIX: Telefon/TCKN/Tepe bölgesi numarası mı kontrol et
    /// - 10-11 haneli salt rakam = muhtemelen telefon veya TCKN
    /// - Salt rakam dizileri (barcode, tracking) fatura no olamaz
    private func isPhoneOrTCKN(_ value: String) -> Bool {
        // Sadece rakamlardan oluşuyor mu?
        let digitsOnly = value.filter { $0.isNumber }
        
        // Salt rakam ise fatura no olamaz (örn: 9806598920 tepe bölgesi sayısı)
        // E-Arşiv formatı en az 3 harf içermeli
        if value == digitsOnly && digitsOnly.count >= 9 {
            return true
        }
        
        // Değerin tamamı rakamsa ve 10-11 hane arasıysa (TCKN/telefon)
        if value == digitsOnly && (digitsOnly.count == 10 || digitsOnly.count == 11) {
            return true
        }
        
        // 0 ile başlıyorsa muhtemelen telefon
        if value.hasPrefix("0") && digitsOnly.count >= 10 {
            return true
        }
        
        return false
    }
    
    /// Fatura numarası geçerlilik kontrolü
    /// Tepe bölgesi sayıları, telefon numaraları ve geçersiz formatları filtreler
    /// - Parameters:
    ///   - candidate: Potansiyel fatura numarası
    ///   - contextY: Bloğun Y koordinatı (0.0 = tepe, 1.0 = alt)
    /// - Returns: Geçerli fatura numarası mı?
    private func isValidInvoiceNumber(_ candidate: String, contextY: CGFloat? = nil) -> Bool {
        // 1. Sayfanın en tepesindeki (Y < 0.1) etiketsiz sayılar NO
        if let y = contextY, y < ExtractionConstants.topMarginNoiseThreshold {
            // Salt sayı ise tepe bölgesinde geçersiz
            if candidate.rangeOfCharacter(from: .letters) == nil {
                return false
            }
        }
        
        // 2. Telefon numarası formatındaysa NO
        if candidate.hasPrefix("0") && candidate.filter({ $0.isNumber }).count == 11 {
            return false
        }
        if candidate.hasPrefix("05") && candidate.count >= 10 {
            return false
        }
        
        // 3. Salt rakam dizisi (9+ hane) fatura no olamaz
        let digitsOnly = candidate.filter { $0.isNumber }
        if candidate == digitsOnly && digitsOnly.count >= 9 {
            return false
        }
        
        // 4. TCKN formatı (10-11 hane salt rakam)
        if candidate == digitsOnly && (digitsOnly.count == 10 || digitsOnly.count == 11) {
            return false
        }
        
        // 5. E-Arşiv formatına uyuyorsa EVET (3 harf + yıl + 9 rakam)
        let eArsivPattern = #"^[A-Z]{3}202[0-9]\d{9}$"#
        if candidate.range(of: eArsivPattern, options: .regularExpression) != nil {
            return true
        }
        
        // 6. En az bir harf içermeli (genel kural)
        return candidate.rangeOfCharacter(from: .letters) != nil
    }
    
    private func extractTotalAmount(from text: String) -> Decimal? {
        let lines = text.uppercased().components(separatedBy: .newlines)
        
        // Öncelik bazlı anahtar kelimeler (Ödenecek Tutar mutlak öncelik)
        // Yüksek öncelikli kelimeler düşük öncelikliden daha güvenilir
        let priorityKeywords: [(keyword: String, priority: Int)] = [
            // Mutlak öncelik - Ödenecek Tutar
            ("ÖDENECEK TUTAR", 150),
            ("ODENECEK TUTAR", 150),
            ("ÖDENECEK", 140),
            ("ODENECEK", 140),
            // Yüksek öncelik - Genel Toplam
            ("GENEL TOPLAM", 90),
            ("VERGİLER DAHİL TOPLAM", 85),
            ("VERGILER DAHIL TOPLAM", 85),
            ("VERGİLİ MAL BEDELİ", 80),
            ("VERGILI MAL BEDELI", 80),
            // Orta öncelik
            ("TOPLAM TUTAR", 60),
            ("TOPLAM", 50),
            // Düşük öncelik - Mal Hizmet Toplamı (ara toplam, ÖDENECEK bulunursa yoksayılır)
            ("MAL HİZMET TOPLAMI", 30),
            ("MAL HIZMET TOPLAMI", 30)
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
        // Esnek tutar regex - OCR varyasyonlarını kapsar
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

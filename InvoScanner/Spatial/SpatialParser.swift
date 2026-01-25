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
        // Fallback 2: Sol üst bölgeden akıllı çıkarım (YENİ)
        if result.supplier == nil {
            result.supplier = extractSupplierFromTopLeft(layoutMap: layoutMap)
        }
        // Fallback 3: Şahıs faturaları için - buyer bloğunun geçerli isim satırı
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
        // Karakter ve ligature temizliği
        let cleanText = text
            .replacingOccurrences(of: "ﬀ", with: "ff")
            .replacingOccurrences(of: "ﬁ", with: "fi")
            .replacingOccurrences(of: "ﬂ", with: "fl")
            .replacingOccurrences(of: "ﬃ", with: "ffi")
            .replacingOccurrences(of: "ﬄ", with: "ffl")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        
        // Etiketli ETTN araması
        let labeledPattern = "(?:ETTN|ETTV)[:]?([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})"
        if let regex = try? NSRegularExpression(pattern: labeledPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleanText, range: NSRange(cleanText.startIndex..., in: cleanText)),
           let captureRange = Range(match.range(at: 1), in: cleanText) {
            return String(cleanText[captureRange])
        }
        
        // Ham UUID araması
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
        // Satır bazlı analiz
        let lines = text.components(separatedBy: .newlines)
            .map { cleanSellerLabel($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !isLabelOnlyLine($0) }
        
        guard !lines.isEmpty else { return nil }
        
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
            
            // Regex ile adres pattern'i tespit et ve kes
            let cleanLine = cutAtAddressPattern(line)
            
            if cleanLine.isEmpty {
                // Adres pattern'i satır başında ise sonraki satırlara geçme
                if isAddressLine(upperLine) { break }
                continue
            }
            
            nameParts.append(cleanLine)
            
            // Adres kesilmişse döngüden çık
            if cleanLine.count < line.count { break }
        }
        
        // Birleştirilmiş ismi al
        let fullName = nameParts.joined(separator: " ")
        
        // Kurumsal Sonek Kontrolü (Hard Cut)
        if !fullName.isEmpty {
            return cleanLeadingNumbers(cleanSellerLabel(applyHardSuffixCut(fullName)))
        }
        
        // Şahıs ismi fallback (2-4 kelime, adres/kargo değil)
        if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) {
            let cutLine = cutAtAddressPattern(firstLine)
            if !cutLine.isEmpty {
                return cleanLeadingNumbers(cleanSellerLabel(cutLine))
            }
        }
        
        return nil
    }
    
    /// Regex ile adres pattern'ini tespit edip öncesini döndürür
    /// Örn: "FAZIL CÖMERT FEVZİÇAKMAK MAH." → "FAZIL CÖMERT"
    private func cutAtAddressPattern(_ text: String) -> String {
        // Adres pattern'leri (regex) - kelime + adres soneki
        // [A-ZÇĞIİÖŞÜ]+ = Türkçe büyük harf kelime
        // Sonra MAH./CAD./SOK. vb.
        let addressPatterns = [
            // "XXXX MAH." veya "XXXX MAHALLESİ" pattern'i
            #"\s+[A-ZÇĞIİÖŞÜa-zçğıiöşü]+\s*(MAH\.|MAHALLESİ|MAHALLESI|MAHALLE)"#,
            // "XXXX CAD." veya "XXXX CADDESİ" pattern'i
            #"\s+[A-ZÇĞIİÖŞÜa-zçğıiöşü]+\s*(CAD\.|CADDESİ|CADDESI|CADDE)"#,
            // "XXXX SOK." veya "XXXX SOKAĞI" pattern'i
            #"\s+[A-ZÇĞIİÖŞÜa-zçğıiöşü]+\s*(SOK\.|SOKAĞI|SOKAGI|SOKAK)"#,
            // "XXXX BULVARI" pattern'i
            #"\s+[A-ZÇĞIİÖŞÜa-zçğıiöşü]+\s*(BULVAR|BULVARI)"#,
            // e-Arşiv etiketleri
            #"\s*Mahalle/Semt:"#,
            #"\s*MAHALLE/SEMT:"#,
            #"\s*Cadde/Sokak:"#,
            #"\s*CADDE/SOKAK:"#,
            // Basit terminatörler (boşlukla)
            #"\s+ADRES\s*:"#,
            #"\s+ADRES\b"#,
            #"\s+NO\s*:"#,
            #"\s+TEL\s*:"#,
            #"\s+VKN\s*:"#,
            #"\s+TCKN\s*:"#
        ]
        
        let upperText = text.uppercased(with: Locale(identifier: "tr_TR"))
        
        for pattern in addressPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: upperText, range: NSRange(upperText.startIndex..., in: upperText)) {
                // Pattern'in başladığı yer
                let matchStart = match.range.location
                
                // Pattern satır başında eşleşirse, tüm satır adres demek
                if matchStart == 0 {
                    return ""
                }
                
                // Pattern ortada eşleşirse, öncesini al
                if let cutIndex = text.index(text.startIndex, offsetBy: matchStart, limitedBy: text.endIndex) {
                    return String(text[..<cutIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Satırın tamamen adres olup olmadığını kontrol eder
    private func isAddressLine(_ upperLine: String) -> Bool {
        // Klasik adres başlangıçları
        let addressStarters = [
            "MAH.", "MAHALLE", "CAD.", "CADDE", "SOK.", "SOKAK",
            "BULVAR", "MEYDAN", "NO:", "KAT:", "DAIRE", "APT", "BLOK"
        ]
        
        for starter in addressStarters {
            if upperLine.hasPrefix(starter) { return true }
        }
        
        // e-Arşiv adres etiketleri
        let eArchiveLabels = [
            "MAHALLE/SEMT:", "MAHALLE/SEMT",
            "CADDE/SOKAK:", "CADDE/SOKAK",
            "ADRES:", "ADRES"
        ]
        
        for label in eArchiveLabels {
            if upperLine.hasPrefix(label) { return true }
            // Küçük harfli versiyonları da kontrol et
            if upperLine.lowercased().hasPrefix(label.lowercased()) { return true }
        }
        
        // Posta kodu ile başlıyorsa
        if upperLine.range(of: #"^\d{5}\b"#, options: .regularExpression) != nil {
            return true
        }
        
        return false
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
    
    /// Sol üst bölgeden satıcı ismini akıllı şekilde çıkarır
    /// Y < 0.40 olan sol kolon bloklarından geçerli isim arar
    private func extractSupplierFromTopLeft(layoutMap: LayoutMap) -> String? {
        // Sol üst bölgedeki bloklar (Y < 0.40)
        let topLeftBlocks = layoutMap.leftColumn.filter { $0.center.y < 0.40 }
        
        for block in topLeftBlocks {
            // buyer veya meta etiketli blokları atla
            if block.label == .buyer || block.label == .meta || block.label == .ettn { continue }
            
            let lines = block.text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            for line in lines {
                // Geçerli isim mi kontrol et
                if isValidPersonOrCompanyName(line) {
                    let cleaned = cutAtAddressPattern(line)
                    if !cleaned.isEmpty && cleaned.count > 3 {
                        return cleanLeadingNumbers(cleanSellerLabel(cleaned))
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Bloktan ilk anlamlı satırı al (şahıs faturaları için)
    /// Etiket satırlarını, tarih/zaman satırlarını atlar, ilk gerçek ismi alır
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
        
        // Tarih/zaman/meta pattern'leri (YENİ - atlaması gerekenler)
        let dateTimeMetaPatterns = [
            #"^\d{1,2}\.\d{1,2}\.\d{4}"#,        // 17.09.2023
            #"^\d{4}-\d{2}-\d{2}"#,               // 2023-09-17
            #"^\d{1,2}:\d{2}"#,                   // 21:03
            #"^e-[Bb]elge"#,                      // e-Belge
            #"^E-?ARŞİV"#,                        // E-ARŞİV
            #"^E-?ARSIV"#,                        // E-ARSIV
            #"^FATURA\s*(NO|TARİHİ|TARIHI)"#,    // FATURA NO/TARİHİ
            #"^SENARYO"#,                         // SENARYO:
            #"^DÜZENLEME"#,                       // DÜZENLEME TARİHİ
            #"^DUZENLEME"#                        // DUZENLEME TARIHI
        ]
        
        for line in lines {
            // Etiket satırı mı?
            let isLabelLine = labelPatterns.contains { pattern in
                line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
            if isLabelLine { continue }
            
            // Tarih/zaman/meta satırı mı?
            let isDateTimeMeta = dateTimeMetaPatterns.contains { pattern in
                line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
            if isDateTimeMeta { continue }
            
            // Geçerli isim mi kontrol et
            if line.count > 3 && isValidPersonOrCompanyName(line) {
                return cleanLeadingNumbers(cutAtAddressPattern(line))
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
    
    /// Satırın geçerli bir şahıs/şirket ismi olup olmadığını kontrol eder
    /// Tarih, zaman, meta etiket ve adres içeren satırları reddeder
    private func isValidPersonOrCompanyName(_ text: String) -> Bool {
        let upper = text.uppercased(with: Locale(identifier: "tr_TR"))
        
        // Tarih içeriyorsa geçersiz (17.09.2023 veya 2023-09-17)
        if text.range(of: #"\d{1,2}\.\d{1,2}\.\d{4}"#, options: .regularExpression) != nil { return false }
        if text.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil { return false }
        
        // Zaman içeriyorsa geçersiz (21:03)
        if text.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil { return false }
        
        // Meta etiketleri içeriyorsa geçersiz
        let metaKeywords = [
            "E-BELGE", "E-ARŞİV", "E-ARSIV", "E-FATURA",
            "FATURA NO", "FATURA TARİHİ", "FATURA TARIHI",
            "SENARYO", "DÜZENLEME", "DUZENLEME",
            "BELGE TARİHİ", "BELGE TARIHI"
        ]
        for keyword in metaKeywords {
            if upper.contains(keyword) { return false }
        }
        
        // Adres kelimeleri içeriyorsa geçersiz
        if upper.contains("MAH.") || upper.contains("MAHALLE") { return false }
        if upper.contains("CAD.") || upper.contains("CADDE") { return false }
        if upper.contains("SOK.") || upper.contains("SOKAK") { return false }
        if upper.contains("BULVAR") || upper.contains("MEYDAN") { return false }
        
        // Minimum 2 kelime olmalı (tek kelime genellikle isim değil)
        let words = text.split(separator: " ").filter { $0.count > 1 }
        if words.count < 1 { return false }
        
        // 10'dan fazla kelime muhtemelen adres veya açıklama
        if words.count > 10 { return false }
        
        return true
    }
    
    /// Sadece etiket içeren satırları tespit eder (filtrele)
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
                let dateStr = String(text[captureRange])
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
    
    /// Tarih metnini Date nesnesine dönüştürür
    private func parseDate(_ rawDateStr: String) -> Date? {
        var dateStr = rawDateStr
        
        // Temizlik işlemleri
        dateStr = dateStr.replacingOccurrences(of: " ", with: "")
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
        
        // Ayraç normalizasyonu
        dateStr = dateStr.replacingOccurrences(of: "/", with: ".")
        dateStr = dateStr.replacingOccurrences(of: "-", with: ".")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.date(from: dateStr)
    }
    
    /// Telefon/TCKN/Tepe bölgesi numarası mı kontrolü
    /// - 10-11 haneli sayı = telefon veya TCKN
    /// - Salt rakamlar fatura no olamaz
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
    private func isValidInvoiceNumber(_ candidate: String, contextY: CGFloat? = nil) -> Bool {
        // 1. Tepe bölgesi (Y < 0.1) salt sayı kontrolü
        if let y = contextY, y < ExtractionConstants.topMarginNoiseThreshold {
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

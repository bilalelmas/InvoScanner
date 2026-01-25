import Foundation

// MARK: - Tutar Doğrulayıcı

/// Sayısal tutarı belgedeki yazıyla (örn: "Yalnız...") karşılaştırır
public struct AmountToTextVerifier {
    
    // MARK: - Doğrulama Sonucu
    
    public struct VerificationResult {
        /// Eşleşme durumu
        public let isMatch: Bool
        /// Benzerlik oranı (0-1)
        public let confidence: Double
        /// Sonuç açıklaması
        public let reason: String
        /// Sayısal tutar
        public let numericAmount: Decimal
        /// Belgeden çıkarılan yazı
        public let textAmount: String?
    }
    
    // MARK: - Türkçe Sayı Kelimeleri
    
    private let units = ["", "BİR", "İKİ", "ÜÇ", "DÖRT", "BEŞ", "ALTI", "YEDİ", "SEKİZ", "DOKUZ"]
    private let tens = ["", "ON", "YİRMİ", "OTUZ", "KIRK", "ELLİ", "ALTMIŞ", "YETMİŞ", "SEKSEN", "DOKSAN"]
    private let scales = ["", "YÜZ", "BİN", "MİLYON", "MİLYAR"]
    
    // MARK: - Ana Doğrulama
    
    /// Sayısal tutarı "Yalnız..." satırıyla karşılaştırır
    public func verify(numericAmount: Decimal, fullText: String) -> VerificationResult {
        let upperText = fullText.uppercased()
        
        // "Yalnız" satırını bul
        guard let yalnizRange = upperText.range(of: "YALNIZ") else {
            return VerificationResult(
                isMatch: false,
                confidence: 0.0,
                reason: "Yalnız satırı bulunamadı",
                numericAmount: numericAmount,
                textAmount: nil
            )
        }
        
        // Yalnız'dan sonraki metni al
        let afterYalniz = String(upperText[yalnizRange.upperBound...])
        let yalnizLine = afterYalniz.components(separatedBy: .newlines).first ?? ""
        
        // Beklenen metni oluştur
        let expectedText = convertToText(numericAmount)
        
        // Benzerlik hesapla
        let similarity = calculateSimilarity(yalnizLine, expectedText)
        
        return VerificationResult(
            isMatch: similarity >= 0.8,
            confidence: similarity,
            reason: similarity >= 0.8 ? "Tutar doğrulandı" : "Tutar eşleşmiyor",
            numericAmount: numericAmount,
            textAmount: yalnizLine.trimmingCharacters(in: .whitespaces)
        )
    }
    
    // MARK: - Sayı → Metin Dönüşümü
    
    /// Sayıyı Türkçe yazıya çevirir (örn: 159.53 → "YÜZ ELLİ DOKUZ TL ELLİ ÜÇ KURUŞ")
    public func convertToText(_ amount: Decimal) -> String {
        let parts = NSDecimalNumber(decimal: amount).doubleValue
        let lira = Int(parts)
        let kurus = Int(round((parts - Double(lira)) * 100))
        
        var result = ""
        
        if lira > 0 {
            result += convertInteger(lira) + " TL"
        }
        
        if kurus > 0 {
            if !result.isEmpty { result += " " }
            result += convertInteger(kurus) + " KURUŞ"
        }
        
        return result.isEmpty ? "SIFIR TL" : result
    }
    
    /// Tamsayıyı Türkçe yazıya çevirir
    private func convertInteger(_ n: Int) -> String {
        guard n > 0 else { return "" }
        
        if n < 10 {
            return units[n]
        } else if n < 100 {
            let t = n / 10
            let u = n % 10
            return (tens[t] + (u > 0 ? " " + units[u] : "")).trimmingCharacters(in: .whitespaces)
        } else if n < 1000 {
            let h = n / 100
            let remainder = n % 100
            let hundredPart = h == 1 ? "YÜZ" : units[h] + " YÜZ"
            return (hundredPart + (remainder > 0 ? " " + convertInteger(remainder) : "")).trimmingCharacters(in: .whitespaces)
        } else if n < 1000000 {
            let thousands = n / 1000
            let remainder = n % 1000
            let thousandPart = thousands == 1 ? "BİN" : convertInteger(thousands) + " BİN"
            return (thousandPart + (remainder > 0 ? " " + convertInteger(remainder) : "")).trimmingCharacters(in: .whitespaces)
        }
        
        return String(n)
    }
    
    // MARK: - Benzerlik Hesaplama
    
    /// Jaccard benzerlik oranı (kesişim / birleşim)
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.uppercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        let words2 = Set(text2.uppercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        
        guard !words1.isEmpty && !words2.isEmpty else { return 0.0 }
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return Double(intersection) / Double(union)
    }
}

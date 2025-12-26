import Foundation

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   Amount to Text Verifier - V5 Akademik Doğrulama
// MARK:   Sayısal tutarı "Yalnız..." satırıyla karşılaştırır
// MARK: ═══════════════════════════════════════════════════════════════════

/// Tutarın yazıyla doğrulanması (Self-Validation)
/// Fatura dipnotundaki "Yalnız Yüz Elli Dokuz TL Elli Üç Kuruş" ile
/// sayısal tutarı (159.53) karşılaştırır.
public struct AmountToTextVerifier {
    
    // MARK: - Verification Result
    
    public struct VerificationResult {
        public let isMatch: Bool
        public let confidence: Double
        public let reason: String
        public let numericAmount: Decimal
        public let textAmount: String?
    }
    
    // MARK: - Turkish Number Words
    
    private let units = ["", "BİR", "İKİ", "ÜÇ", "DÖRT", "BEŞ", "ALTI", "YEDİ", "SEKİZ", "DOKUZ"]
    private let tens = ["", "ON", "YİRMİ", "OTUZ", "KIRK", "ELLİ", "ALTMIŞ", "YETMİŞ", "SEKSEN", "DOKSAN"]
    private let scales = ["", "BİN", "MİLYON", "MİLYAR"]
    
    // MARK: - Main Verification
    
    /// Sayısal tutarı belgedeki "Yalnız..." yazısıyla doğrular
    /// - Parameters:
    ///   - numericAmount: Çıkarılan sayısal tutar (örn: 159.53)
    ///   - fullText: Tüm belge metni
    /// - Returns: Doğrulama sonucu
    public func verify(numericAmount: Decimal, fullText: String) -> VerificationResult {
        // "Yalnız" satırını bul
        let upperText = fullText.uppercased()
        guard let yalnizRange = upperText.range(of: "YALNIZ") else {
            return VerificationResult(
                isMatch: false,
                confidence: 0.0,
                reason: "Yalnız satırı bulunamadı",
                numericAmount: numericAmount,
                textAmount: nil
            )
        }
        
        // Yalnız'dan sonraki satırı al
        let afterYalniz = String(upperText[yalnizRange.upperBound...])
        let yalnizLine = afterYalniz.components(separatedBy: .newlines).first ?? ""
        
        // Sayıyı metne çevir
        let expectedText = convertToText(numericAmount)
        
        // Karşılaştır
        let similarity = calculateSimilarity(yalnizLine, expectedText)
        
        return VerificationResult(
            isMatch: similarity >= 0.8,
            confidence: similarity,
            reason: similarity >= 0.8 ? "Tutar doğrulandı" : "Tutar eşleşmiyor",
            numericAmount: numericAmount,
            textAmount: yalnizLine.trimmingCharacters(in: .whitespaces)
        )
    }
    
    // MARK: - Number to Text Conversion
    
    /// Sayıyı Türkçe metne çevirir
    /// Örn: 159.53 → "YÜZ ELLİ DOKUZ TL ELLİ ÜÇ KURUŞ"
    public func convertToText(_ amount: Decimal) -> String {
        let parts = NSDecimalNumber(decimal: amount).doubleValue
        let lira = Int(parts)
        let kurus = Int(round((parts - Double(lira)) * 100))
        
        var result = ""
        
        // Lira kısmı
        if lira > 0 {
            result += convertInteger(lira) + " TL"
        }
        
        // Kuruş kısmı
        if kurus > 0 {
            if !result.isEmpty { result += " " }
            result += convertInteger(kurus) + " KURUŞ"
        }
        
        return result.isEmpty ? "SIFIR TL" : result
    }
    
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
        
        return String(n) // Fallback
    }
    
    // MARK: - Similarity Calculation
    
    /// İki metin arasındaki benzerlik oranını hesaplar (0-1)
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.uppercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        let words2 = Set(text2.uppercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        
        guard !words1.isEmpty && !words2.isEmpty else { return 0.0 }
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return Double(intersection) / Double(union)
    }
}

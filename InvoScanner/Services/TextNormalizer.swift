import Foundation

/// OCR ve ham metin verilerini normalize etmek için kullanılan yardımcı sınıf.
/// Bu sınıf, Türkçe karakterleri standartlaştırır, boşlukları temizler ve
/// metni analiz için en uygun formata (UPPERCASE) getirir.
struct TextNormalizer {
    
    /// Verilen metni normalize eder.
    /// - Parameter text: Ham metin.
    /// - Returns: Normalize edilmiş, büyük harfli ve temizlenmiş metin.
    static func normalize(_ text: String) -> String {
        // 1. Büyük harfe çevir (Locale duyarlı)
        var normalized = text.uppercased(with: Locale(identifier: "tr_TR"))
        
        // 2. Türkçe karakterleri İngilizce karşılıklarına dönüştür
        // İ -> I, Ş -> S, Ğ -> G, Ö -> O, Ü -> U, Ç -> C
        let replacements: [String: String] = [
            "İ": "I",
            "Ş": "S",
            "Ğ": "G",
            "Ö": "O",
            "Ü": "U",
            "Ç": "C",
            "ı": "I", // Emniyet için küçük harf kontrolü de (uppercased sonrası gereksiz olabilir ama OCR hatası için)
            "ş": "S",
            "ğ": "G",
            "ö": "O",
            "ü": "U",
            "ç": "C"
        ]
        
        for (original, replacement) in replacements {
            normalized = normalized.replacingOccurrences(of: original, with: replacement)
        }
        
        // 3. Çoklu boşlukları tek boşluğa indir
        // Regex: \s+ -> " "
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 4. Ayırıcıları standartlaştır
        // ":" -> ": " (Yapışık iki nokta üst üste ayrımı)
        // Örnek: "ETTN:123" -> "ETTN: 123"
        // Ancak önce zaten olan boşlukları bozmamak için basit bir replace yapıyoruz,
        // ardından tekrar oluşan çift boşlukları siliyoruz.
        normalized = normalized.replacingOccurrences(of: ":", with: ": ")
        normalized = normalized.replacingOccurrences(of: "  ", with: " ") // Olası çift boşluk temizliği
        
        // 5. Baş ve sondaki boşlukları temizle
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return normalized
    }
}

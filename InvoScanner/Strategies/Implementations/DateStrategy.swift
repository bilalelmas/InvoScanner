import Foundation

/// V2 Tarih Ayrıştırma Stratejisi
/// - Özellikler: Çoklu format desteği, bağlamsal anahtar kelime önceliği
/// - ÖNEMLİ: Geçersiz veya bulunamayan tarihlerde nil döner (Date() KULLANILMAZ)
struct DateStrategy: ExtractionStrategy {
    typealias ResultType = Date
    
    func extract(from blocks: [TextBlock]) -> Date? {
        let dateKeywords = ["Düzenleme Tarihi", "Fatura Tarihi", "Tarih"]
        
        // 1. Yakınlık Araması: Anahtar kelimelerin yanındaki blokları ara
        for block in blocks {
            for keyword in dateKeywords {
                if block.text.localizedCaseInsensitiveContains(keyword) {
                    // Bu bloğu kontrol et
                    if let date = findDate(in: block.text) { return date }
                    
                    // Yakındaki blokları kontrol et (şimdilik basit sonraki blok kontrolü, uzamsal mantıkla geliştirilebilir)
                    // Gerçek bir uzamsal uygulamada, sağdaki veya altındaki blokları arardık.
                    // Şimdilik, liste sırasına güveniyoruz ancak uzamsal sıralama olmadan güvenilir olmayabilir.
                    // Bağlamsal anahtar kelime başarısız olursa sağlam bir yedekleme için hepsini tekrar yineleyelim.
                }
            }
        }
        
        // 2. Yedek: Regex eşleşmesi için tüm blokları tara
        for block in blocks {
            if let date = findDate(in: block.text) {
                return date
            }
        }
        
        return nil
    }
    
    private func findDate(in text: String) -> Date? {
        // Supports: dd-MM-yyyy, dd.MM.yyyy, dd/MM/yyyy
        let patterns = [
            "\\b\\d{2}-\\d{2}-\\d{4}\\b",
            "\\b\\d{2}\\.\\d{2}\\.\\d{4}\\b",
            "\\b\\d{2}/\\d{2}/\\d{4}\\b"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {
                let dateString = (text as NSString).substring(with: match.range)
                return parseDate(dateString)
            }
        }
        return nil
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        let formats = ["dd-MM-yyyy", "dd.MM.yyyy", "dd/MM/yyyy"]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}

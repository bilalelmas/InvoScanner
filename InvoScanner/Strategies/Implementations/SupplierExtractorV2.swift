import Foundation

/// V1 Satıcı Tespit Algoritması
/// Satıcı, VKN/TCKN vergi bloğunun üstündeki ilk geçerli satırdır.
struct SupplierExtractorV2 {
    
    // Vergi bloğu başlangıç anahtar kelimeleri
    private let taxKeywords = ["VKN", "VERGI NO", "VERGI DAIRESI", "TCKN", "TC KIMLIK"]
    
    // Durma kelimeleri (Bu satırlar satıcı olamaz)
    private let stopWords = ["E-ARSIV", "FATURA", "SAYIN", "TESLIMAT", "FATURA ADRESI", "MUSTERI", "ALICI"]
    
    // Kurumsal şirket anahtar kelimeleri
    private let corporateKeywords = ["LTD", "LIMITED", "A.S.", "A.S", "AS.", "ANONIM", "TICARET", "SIRKETI", "TIC."]
    
    /// Normalize edilmiş metinden satıcı adını çıkarır.
    /// - Parameter text: Normalize edilmiş tam metin (UPPERCASE, TR char fix done)
    /// - Returns: Tespit edilen satıcı adı veya nil
    func extract(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        
        // 1. Vergi bloğu satırını bul
        guard let taxLineIndex = findTaxBlockIndex(in: lines) else {
            print("SupplierV2: Vergi bloğu bulunamadı.")
            return nil
        }
        
        print("SupplierV2: Vergi bloğu satır \(taxLineIndex)'de bulundu: \(lines[taxLineIndex])")
        
        // 2. Yukarı doğru tara
        for i in stride(from: taxLineIndex - 1, through: 0, by: -1) {
            let line = lines[i]
            
            // Boş satırları atla
            if line.isEmpty { continue }
            
            // Stop-word kontrolü
            if containsStopWord(line) {
                print("SupplierV2: Stop-word bulundu, tarama durdu: \(line)")
                break
            }
            
            // Geçerli satıcı satırı mı?
            if isValidSupplierLine(line) {
                print("SupplierV2: Satıcı bulundu: \(line)")
                return cleanSupplierName(line)
            }
        }
        
        print("SupplierV2: Geçerli satıcı satırı bulunamadı.")
        return nil
    }
    
    // MARK: - Helpers
    
    private func findTaxBlockIndex(in lines: [String]) -> Int? {
        for (index, line) in lines.enumerated() {
            for keyword in taxKeywords {
                if line.contains(keyword) {
                    return index
                }
            }
        }
        return nil
    }
    
    private func containsStopWord(_ line: String) -> Bool {
        for stopWord in stopWords {
            if line.contains(stopWord) {
                return true
            }
        }
        return false
    }
    
    private func isValidSupplierLine(_ line: String) -> Bool {
        let words = line.split(separator: " ")
        
        // En az 2 kelime
        guard words.count >= 2 else { return false }
        
        // Rakam oranı %20'den düşük olmalı
        let digitCount = line.filter { $0.isNumber }.count
        let digitRatio = Double(digitCount) / Double(line.count)
        if digitRatio > 0.20 { return false }
        
        // Kurumsal anahtar kelime varsa bonus (ama zorunlu değil)
        // Şahıs firmaları için de geçerli olmalı
        
        return true
    }
    
    private func cleanSupplierName(_ line: String) -> String {
        // Başındaki ve sonundaki gereksiz karakterleri temizle
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Satır başındaki numaraları veya işaretleri temizle
        cleaned = cleaned.replacingOccurrences(of: "^[0-9\\-\\.\\*\\:]+\\s*", with: "", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

import Foundation
import CoreGraphics

/// V3 Tutar Ayrıştırma Stratejisi
/// - Özellikler: Footer önceliği, en büyük sayı tespiti, matematiksel doğrulama
struct AmountStrategy: ExtractionStrategy {
    typealias ResultType = Decimal
    
    // MARK: - Main Extraction
    
    func extract(from blocks: [TextBlock]) -> Decimal? {
        // Sayfanın alt %40'lık kısmını filtrele (esnek aralık)
        let bottomBlocks = blocks.filter { $0.frame.minY > 0.6 }
        
        // Adım 1: Footer'da anahtar kelime ile eşleşme
        if let keywordMatch = extractWithKeyword(from: bottomBlocks) {
            return keywordMatch
        }
        
        // Adım 2: Alt bölgedeki en büyük sayı
        if let largestAmount = extractLargestAmount(from: bottomBlocks) {
            return largestAmount
        }
        
        // Adım 3: Tüm bloklar üzerinden fallback
        return extractLargestAmount(from: blocks)
    }
    
    // MARK: - V3: Matematik Doğrulamalı Çıkarım
    
    /// Matrah, KDV ve Toplam tutarları çıkararak matematiksel doğrulama yapar
    /// - Kural: |Matrah + KDV - Toplam| < 0.05
    func extractWithValidation(from text: String) -> (total: Decimal, isValid: Bool)? {
        // Matrah (Vergisiz Tutar) keywords
        let matrahKeywords = ["MATRAH", "VERGISIZ TUTAR", "ARA TOPLAM", "SUBTOTAL"]
        // KDV keywords
        let kdvKeywords = ["KDV", "HESAPLANAN KDV", "VAT", "VERGI"]
        // Toplam keywords
        let toplamKeywords = ["GENEL TOPLAM", "ÖDENECEK TUTAR", "TOPLAM", "GRAND TOTAL"]
        
        let lines = text.uppercased().components(separatedBy: .newlines)
        
        var matrah: Decimal?
        var kdv: Decimal?
        var toplam: Decimal?
        
        for line in lines {
            // Matrah tespiti
            if matrah == nil {
                for keyword in matrahKeywords {
                    if line.contains(keyword) {
                        matrah = extractNumbers(from: line).first
                        break
                    }
                }
            }
            
            // KDV tespiti
            if kdv == nil {
                for keyword in kdvKeywords {
                    if line.contains(keyword) && !line.contains("MATRAH") {
                        kdv = extractNumbers(from: line).first
                        break
                    }
                }
            }
            
            // Toplam tespiti
            for keyword in toplamKeywords {
                if line.contains(keyword) {
                    if let amount = extractNumbers(from: line).max() {
                        toplam = amount
                    }
                }
            }
        }
        
        // Matematiksel doğrulama
        if let m = matrah, let k = kdv, let t = toplam {
            let calculated = m + k
            let difference = abs(NSDecimalNumber(decimal: calculated - t).doubleValue)
            let isValid = difference < 0.05
            
            print("AmountV3: Matrah=\(m), KDV=\(k), Toplam=\(t), Fark=\(difference), Geçerli=\(isValid)")
            return (t, isValid)
        }
        
        // Sadece toplam bulunduysa
        if let t = toplam {
            print("AmountV3: Sadece Toplam bulundu=\(t), Doğrulama yapılamadı")
            return (t, false)
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func extractWithKeyword(from blocks: [TextBlock]) -> Decimal? {
        let amountKeywords = ["Genel Toplam", "Ödenecek Tutar", "Toplam"]
        var maxAmount: Decimal = 0.0
        var foundAmount: Decimal?
        
        for block in blocks {
            for keyword in amountKeywords {
                if block.text.localizedCaseInsensitiveContains(keyword) {
                    let numbers = extractNumbers(from: block.text)
                    if let maxInBlock = numbers.max(), maxInBlock > maxAmount {
                        maxAmount = maxInBlock
                        foundAmount = maxInBlock
                    }
                }
            }
        }
        
        return foundAmount
    }
    
    private func extractLargestAmount(from blocks: [TextBlock]) -> Decimal? {
        var maxAmount: Decimal = 0.0
        
        for block in blocks {
            let numbers = extractNumbers(from: block.text)
            if let maxInBlock = numbers.max(), maxInBlock > maxAmount {
                maxAmount = maxInBlock
            }
        }
        
        return maxAmount > 0 ? maxAmount : nil
    }
    
    private func extractNumbers(from text: String) -> [Decimal] {
        // TR format: 1.000,00 -> 1000.00
        let component = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
        let parts = component.split(separator: " ").map { String($0) }
        var decimals: [Decimal] = []
        
        for part in parts {
            let cleanPart = part.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            if let doubleVal = Double(cleanPart) {
                decimals.append(Decimal(doubleVal))
            }
        }
        
        return decimals
    }
}

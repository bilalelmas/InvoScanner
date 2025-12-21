import Foundation
import CoreGraphics

struct AmountStrategy: ExtractionStrategy {
    typealias ResultType = Decimal
    
    func extract(from blocks: [TextBlock]) -> Decimal? {
        // Sayfanın alt %30'luk kısmını filtrele
        // Normalize koordinatlar 0..1, alt kısım > 0.7
        let bottomBlocks = blocks.filter { $0.frame.minY > 0.6 } // biraz esnek %40
        
        var maxAmount: Decimal = 0.0
        var foundAmount: Decimal?
        
        let amountKeywords = ["Genel Toplam", "Ödenecek Tutar", "Toplam"]
        
        // Strateji: Önce alt bölgede belirli anahtar kelimeleri ara
        for block in bottomBlocks {
            for keyword in amountKeywords {
                 if block.text.localizedCaseInsensitiveContains(keyword) {
                      // Bu satırdan veya yakınından ayıklamaya çalış
                      // Basitleştirilmiş: bu bloktaki sayıları kontrol et
                      let numbers = extractNumbers(from: block.text)
                      if let maxInBlock = numbers.max() {
                          if maxInBlock > maxAmount {
                              maxAmount = maxInBlock
                              foundAmount = maxInBlock
                          }
                      }
                 }
            }
        }
        
        // Anahtar kelime eşleşmesi bulunamazsa, alt bölgedeki en büyük sayıya bak
        // Bu bir sezgisel yöntemdir: toplam tutar genellikle alttaki en büyük sayıdır.
        if foundAmount == nil {
            for block in bottomBlocks {
                let numbers = extractNumbers(from: block.text)
                if let maxInBlock = numbers.max(), maxInBlock > maxAmount {
                    maxAmount = maxInBlock
                    foundAmount = maxInBlock
                }
            }
        }

        return foundAmount
    }
    
    private func extractNumbers(from text: String) -> [Decimal] {
        // Para birimi sembollerini ve virgül/nokta dışındaki sayısal olmayan karakterleri kaldır
        // Standartlaştır: 1.250,50 -> 1250.50
        // Durumlar:
        // 1) 1.200,50 (TR) -> . boş ile, , nokta ile değiştir
        // 2) 1,200.50 (US) -> , boş ile değiştir (Burada TR öncelikli)
        
        // e-Arşiv bağlamı için TR formatı öncelikli
        // dizeyi temizle
        let component = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
        
        // This is a naive extraction, in production needs robust locale handling.
        // Assuming TR locale for numbers: 1.000,00
        
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

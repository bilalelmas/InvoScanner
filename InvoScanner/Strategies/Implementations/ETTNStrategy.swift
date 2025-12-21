import Foundation
import CoreGraphics

struct ETTNStrategy: ExtractionStrategy {
    typealias ResultType = UUID
    
    func extract(from blocks: [TextBlock]) -> UUID? {
        // Blokları yukarıdan aşağıya işlemek için dikey konuma göre sırala
        let sortedBlocks = blocks.sorted { $0.frame.minY < $1.frame.minY }
        
        for (index, block) in sortedBlocks.enumerated() {
            if block.text.contains("ETTN") {
                // Mevcut blokta UUID kontrolü yap
                if let uuid = findUUID(in: block.text) {
                    return uuid
                }
                
                // Bölünmüş satır senaryosu: ETTN etiketi ve değeri bitişik bloklarda olabilir
                if index + 1 < sortedBlocks.count {
                    let nextBlock = sortedBlocks[index + 1]
                    // Detaylı bölünmüş satır mantığı: Genellikle ETTN etiketi bir satırda, değer sonraki satırdadır
                    // Sağlam kontrol için bir sonraki bloku kontrol et
                     if let uuid = findUUID(in: nextBlock.text) {
                        return uuid
                    }
                    
                    // Birleştirmeyi dene
                    let combined = block.text + " " + nextBlock.text
                    if let uuid = findUUID(in: combined) {
                        return uuid
                    }
                }
            }
        }
        
        // Yedek: Anahtar kelime araması başarısız olursa tüm bloklarda geçerli bir UUID tara
        for block in blocks {
             if let uuid = findUUID(in: block.text) {
                return uuid
            }
        }
        
        return nil
    }
    
    private func findUUID(in text: String) -> UUID? {
        // Regex for UUID
        let pattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first {
            let uuidString = nsString.substring(with: match.range)
            return UUID(uuidString: uuidString)
        }
        
        return nil
    }
}

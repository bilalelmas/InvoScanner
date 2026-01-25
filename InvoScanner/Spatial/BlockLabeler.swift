import Foundation
import CoreGraphics

// MARK: - Blok Etiketleyici

/// Konum ve içerik analiziyle semantik etiketleme yapan motor
///
/// **Puanlama Sistemi:**
/// 1. Konum Puanı: Bloğun bulunduğu bölgeye göre (sol-üst, sağ-alt vb.)
/// 2. İçerik Puanı: Anahtar kelime ağırlıkları
/// 3. Negatif Puan: Çelişen sinyaller (örn. satıcı bloğunda "Sayın")
public struct BlockLabeler {
    
    // MARK: - Yapılandırma
    
    public struct Config {
        /// Üst bölge sınırı
        public let topThreshold: CGFloat
        /// Alt bölge sınırı
        public let bottomThreshold: CGFloat
        /// Sol bölge sınırı
        public let leftThreshold: CGFloat
        /// Sağ bölge sınırı
        public let rightThreshold: CGFloat
        
        public static let standard = Config(
            topThreshold: 0.45,
            bottomThreshold: 0.60,
            leftThreshold: 0.50,
            rightThreshold: 0.50
        )
    }
    
    private let config: Config
    
    public init(config: Config = .standard) {
        self.config = config
    }
    
    // MARK: - İçerik Sinyalleri
    
    /// Satıcı belirteçleri ve ağırlıkları
    private let sellerSignals: [(keyword: String, weight: Double)] = [
        ("SATICI", 50),
        ("VKN", 30),
        ("VERGI KIMLIK", 30),
        ("MERSIS", 25),
        ("TICARET", 20),
        ("TİCARET", 20),
        ("LTD", 20),
        ("A.Ş", 20),
        ("A.S", 20),
        ("AŞ", 15),
        ("SANAYI", 15),
        ("SANAYİ", 15),
        ("VERGI DAIRESI", 15),
        ("VERGİ DAİRESİ", 15)
    ]
    
    /// Alıcı belirteçleri (satıcı için negatif etki yapar)
    private let buyerSignals: [(keyword: String, weight: Double)] = [
        ("SAYIN", 40),
        ("ALICI", 35),
        ("MÜŞTERİ", 30),
        ("MUSTERI", 30),
        ("TESLIM ADRESI", 25),
        ("TESLİM ADRESİ", 25),
        ("TESLIMAT", 20)
    ]
    
    /// Fatura detay belirteçleri (No, Tarih vb.)
    private let metaSignals: [(keyword: String, weight: Double)] = [
        ("FATURA NO", 40),
        ("BELGE NO", 35),
        ("DUZENLEME TARIHI", 30),
        ("DÜZENLEME TARİHİ", 30),
        ("TARIH", 20),
        ("TARİH", 20),
        ("SAAT", 15),
        ("SENARYO", 15)
    ]
    
    /// Toplam tutar belirteçleri
    private let totalsSignals: [(keyword: String, weight: Double)] = [
        ("GENEL TOPLAM", 40),
        ("ODENECEK TUTAR", 40),
        ("ÖDENECEK TUTAR", 40),
        ("TOPLAM", 25),
        ("KDV", 20),
        ("MATRAH", 20),
        ("ARA TOPLAM", 15),
        ("VERGI", 15),
        ("VERGİ", 15)
    ]
    
    /// Gereksiz bilgi belirteçleri (IBAN, QR vb.)
    private let noiseSignals: [(keyword: String, weight: Double)] = [
        ("IBAN", 50),
        ("BANKA", 30),
        ("QR", 25),
        ("KARE KOD", 25),
        ("E-IMZA", 20),
        ("E-İMZA", 20)
    ]
    
    /// ETTN (UUID) formatı için düzenli ifade
    private let uuidRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
            options: []
        )
    }()
    
    // MARK: - Ana Etiketleme Süreci
    
    /// Blok listesini etiketler
    public static func label(blocks: [SemanticBlock]) -> [LabeledBlock] {
        let labeler = BlockLabeler()
        return labeler.performLabeling(blocks)
    }
    
    /// Örnek üzerinden etiketleme yapar
    public func performLabeling(_ blocks: [SemanticBlock]) -> [LabeledBlock] {
        return blocks.map { block in
            var labeledBlock = block
            labeledBlock.label = determineLabel(for: block)
            return labeledBlock
        }
    }
    
    // MARK: - Etiket Karar Mekanizması
    
    /// Puanlama yaparak en uygun etiketi belirler
    private func determineLabel(for block: SemanticBlock) -> BlockLabel {
        let text = block.text.uppercased()
        let center = block.center
        let lineCount = block.children.count
        
        if containsUUID(text) {
            let sellerKeywordCount = countSellerKeywords(in: text)
            // Çok satırlı ve satıcı anahtar kelimesi içeren blokları koru
            if lineCount >= 3 && sellerKeywordCount >= 2 {
                // ETTN ayrıca aranacak
            } else {
                return .ettn
            }
        }
        
        // PUANLAMA: Her aday etiket için skor hesapla
        var scores: [BlockLabel: Double] = [:]
        
        scores[.seller] = calculateSellerScore(text: text, position: center, lineCount: lineCount)
        scores[.buyer] = calculateBuyerScore(text: text, position: center)
        scores[.meta] = calculateMetaScore(text: text, position: center)
        scores[.totals] = calculateTotalsScore(text: text, position: center)
        scores[.noise] = calculateNoiseScore(text: text, position: center)
        
        // KARAR: Belirli bir güven eşiğinin üzerindeki en yüksek skoru seç
        let bestLabel = scores
            .filter { $0.value > 30 }
            .max { $0.value < $1.value }?
            .key
        
        return bestLabel ?? .unknown
    }
    
    /// Metindeki satıcı anahtar kelime sayısını döner
    private func countSellerKeywords(in text: String) -> Int {
        let keywords = ["VKN", "LTD", "A.Ş", "AŞ", "TİCARET", "TICARET", "SANAYİ", "SANAYI", "MERSIS"]
        return keywords.filter { text.contains($0) }.count
    }
    
    // MARK: - Skor Hesaplama Metotları
    
    /// Satıcı skoru: Sol-üst bölge ve şirket unvan belirteçleri
    private func calculateSellerScore(text: String, position: CGPoint, lineCount: Int = 1) -> Double {
        var score: Double = 0
        
        // Konum bonusu
        if position.y < config.topThreshold && position.x < config.leftThreshold {
            score += 40
        } else if position.y < config.topThreshold {
            score += 20
        }
        
        // İçerik bonusu
        score += calculateContentScore(text: text, signals: sellerSignals)
        
        // Çoklu anahtar kelime takviyesi
        let keywordCount = countSellerKeywords(in: text)
        if keywordCount >= 3 {
            score += 50
        } else if keywordCount >= 2 {
            score += 25
        }
        
        // Negatif ceza: Alıcı sinyalleri varsa puan düşür
        let buyerPenalty = calculateContentScore(text: text, signals: buyerSignals)
        if buyerPenalty > 0 {
            score -= buyerPenalty * 1.5
        }
        
        // LOJİSTİK KONTROLÜ: Kargo firmaları asla satıcı olamaz
        let logisticKeywords = ["GÖNDERİ TAŞIYAN", "GONDERI TASIYAN", "TAŞIYAN", "TASIYAN",
                                "KARGO", "LOJİSTİK", "LOJISTIK", "NAKLİYE", "NAKLIYE", "DAĞITIM", "DAGITIM"]
        for keyword in logisticKeywords {
            if text.contains(keyword) {
                return -1000.0
            }
        }
        
        return max(0, score)
    }
    
    /// Alıcı skoru: Sol sütun, satıcı altı ve spesifik hitaplar
    private func calculateBuyerScore(text: String, position: CGPoint) -> Double {
        var score: Double = 0
        
        // Konum bonusu
        if position.x < config.leftThreshold && position.y >= 0.20 && position.y < config.bottomThreshold {
            score += 25
        }
        
        // İçerik bonusu
        score += calculateContentScore(text: text, signals: buyerSignals)
        
        // Çelişki kontrolü
        if text.contains("SATICI") && !text.contains("ALICI") {
            score -= 100
        }
        
        return max(0, score)
    }
    
    /// Meta skoru: Sağ-üst bölge ve fatura no/tarih belirteçleri
    private func calculateMetaScore(text: String, position: CGPoint) -> Double {
        var score: Double = 0
        
        if position.y < config.topThreshold && position.x > config.rightThreshold {
            score += 40
        } else if position.x > config.rightThreshold {
            score += 15
        }
        
        score += calculateContentScore(text: text, signals: metaSignals)
        return max(0, score)
    }
    
    /// Toplamlar skoru: Sağ-alt bölge ve finansal anahtar kelimeler
    private func calculateTotalsScore(text: String, position: CGPoint) -> Double {
        var score: Double = 0
        
        if position.y > config.bottomThreshold && position.x > config.rightThreshold {
            score += 45
        } else if position.y > config.bottomThreshold {
            score += 20
        }
        
        score += calculateContentScore(text: text, signals: totalsSignals)
        return max(0, score)
    }
    
    /// Gürültü skoru: Banka bilgileri, QR ve tepe bölgesi izole sayılar
    private func calculateNoiseScore(text: String, position: CGPoint? = nil) -> Double {
        var score = calculateContentScore(text: text, signals: noiseSignals)
        
        // Tepe bölgesi izole sayı kontrolü (Y < 0.10)
        if let pos = position, pos.y < ExtractionConstants.topMarginNoiseThreshold {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let digitsOnly = trimmedText.filter { $0.isNumber }
            
            if trimmedText == digitsOnly && digitsOnly.count >= 9 {
                score += 100
            }
        }
        
        return score
    }
    
    // MARK: - Yardımcı Metotlar
    
    /// Anahtar kelime eşleşmesi üzerinden puan hesaplar
    private func calculateContentScore(text: String, signals: [(keyword: String, weight: Double)]) -> Double {
        var score: Double = 0
        for (keyword, weight) in signals {
            if text.contains(keyword) {
                score += weight
            }
        }
        return score
    }
    
    /// Metnin UUID (ETTN) formatında olup olmadığını kontrol eder
    private func containsUUID(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return uuidRegex.firstMatch(in: text, options: [], range: range) != nil
    }
}

// MARK: - Pratik Eklentiler

extension BlockLabeler {
    /// Bilinmeyenleri temizleyerek etiketleme yapar
    public func labelAndFilter(_ blocks: [SemanticBlock]) -> [LabeledBlock] {
        return performLabeling(blocks).filter { $0.label != .unknown }
    }
    
    /// Hata ayıklama çıktısı üretir
    public func debugLabel(_ blocks: [SemanticBlock]) {
        #if DEBUG
        for block in blocks {
            let label = determineLabel(for: block)
            let preview = String(block.text.prefix(50)).replacingOccurrences(of: "\n", with: " ")
            print("[\(label.rawValue)] \(preview)...")
        }
        #endif
    }
}

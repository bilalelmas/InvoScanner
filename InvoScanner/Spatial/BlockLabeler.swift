import Foundation
import CoreGraphics

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK:   Block Labeler
// MARK:   Assigns semantic labels using Position + Content Heuristics
// MARK: ═══════════════════════════════════════════════════════════════════

/// Konumsal ve içerik tabanlı semantik etiketleme motoru.
///
/// **Puanlama Sistemi:**
/// Her aday etiket, aşağıdaki kriterlere göre bir puan alır:
/// 1. **Konum Puanı**: Kadran bazlı (sol-üst, sağ-üst, vb.)
/// 2. **İçerik Puanı**: Ağırlıklı anahtar kelime eşleştirme
/// 3. **Negatif Puan**: Çelişen sinyaller güveni düşürür
///
/// En yüksek puanı alan etiket kazanır.
public struct BlockLabeler {
    
    // MARK: - Configuration
    
    public struct Config {
        /// Y threshold for "top" region (above this is top)
        public let topThreshold: CGFloat
        /// Y threshold for "bottom" region (below this is bottom)
        public let bottomThreshold: CGFloat
        /// X threshold for "left" region (below this is left)
        public let leftThreshold: CGFloat
        /// X threshold for "right" region (above this is right)
        public let rightThreshold: CGFloat
        
        public static let standard = Config(
            topThreshold: 0.45,  // Satıcı bilgileri fatuanın üst yarısına yayılabilir
            bottomThreshold: 0.60,
            leftThreshold: 0.50,
            rightThreshold: 0.50
        )
    }
    
    private let config: Config
    
    public init(config: Config = .standard) {
        self.config = config
    }
    
    // MARK: - Content Signals (Keywords)
    
    /// Seller block signals with weights
    private let sellerSignals: [(keyword: String, weight: Double)] = [
        // Explicit seller label
        ("SATICI", 50),  // "Satıcı (Merkez):" vb.
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
    
    /// Buyer block signals (also used as NEGATIVE for seller)
    private let buyerSignals: [(keyword: String, weight: Double)] = [
        ("SAYIN", 40),
        ("ALICI", 35),
        ("MÜŞTERİ", 30),
        ("MUSTERI", 30),
        ("TESLIM ADRESI", 25),
        ("TESLİM ADRESİ", 25),
        ("TESLIMAT", 20)
    ]
    
    /// Meta block signals (Invoice details)
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
    
    /// Totals block signals
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
    
    /// Noise signals (bank info, QR markers, etc.)
    private let noiseSignals: [(keyword: String, weight: Double)] = [
        ("IBAN", 50),
        ("BANKA", 30),
        ("QR", 25),
        ("KARE KOD", 25),
        ("E-IMZA", 20),
        ("E-İMZA", 20)
    ]
    
    /// UUID regex for ETTN detection (8-4-4-4-12 format)
    private let uuidRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
            options: []
        )
    }()
    
    // MARK: - Main Labeling Entry Point
    
    /// Labels an array of semantic blocks.
    ///
    /// - Parameter blocks: Input semantic blocks (from BlockClusterer)
    /// - Returns: Array of labeled blocks
    public static func label(blocks: [SemanticBlock]) -> [LabeledBlock] {
        let labeler = BlockLabeler()
        return labeler.performLabeling(blocks)
    }
    
    /// Instance method for labeling with custom configuration
    public func performLabeling(_ blocks: [SemanticBlock]) -> [LabeledBlock] {
        return blocks.map { block in
            var labeledBlock = block
            labeledBlock.label = determineLabel(for: block)
            return labeledBlock
        }
    }
    
    // MARK: - Label Determination
    
    /// Determines the best label for a semantic block using scoring.
    ///
    /// - Parameter block: The semantic block to label
    /// - Returns: The highest-scoring label
    private func determineLabel(for block: SemanticBlock) -> BlockLabel {
        let text = block.text.uppercased()
        let center = block.center
        let lineCount = block.children.count
        
        // ──────────────────────────────────────────────────────────────
        // PRIORITY 1: ETTN (UUID Detection) - POSITION INDEPENDENT
        // ──────────────────────────────────────────────────────────────
        // UUID formatı içeren bloklar, konumu ne olursa olsun (sağ, sol, alt, üst)
        // ETTN olarak etiketlenir. Sadece satıcı bloğu istisnası korunur.
        if containsUUID(text) {
            // Koruma: Uzun blok (3+ satır) ve 2+ satıcı anahtar kelimesi varsa
            // Bu muhtemelen satıcı bilgileri bloğu, ETTN ayrı çıkarılacak
            let sellerKeywordCount = countSellerKeywords(in: text)
            if lineCount >= 3 && sellerKeywordCount >= 2 {
                // Satıcı bloğu olarak devam et, ETTN olarak işaretleme
                // ETTN küresel arama ile yakalanacak
            } else {
                // Konum kontrolü YOK - UUID varsa ETTN'dir
                return .ettn
            }
        }
        
        // ──────────────────────────────────────────────────────────────
        // SCORING: Calculate scores for each candidate label
        // ──────────────────────────────────────────────────────────────
        var scores: [BlockLabel: Double] = [:]
        
        // Seller Score
        scores[.seller] = calculateSellerScore(text: text, position: center, lineCount: lineCount)
        
        // Buyer Score
        scores[.buyer] = calculateBuyerScore(text: text, position: center)
        
        // Meta Score
        scores[.meta] = calculateMetaScore(text: text, position: center)
        
        // Totals Score
        scores[.totals] = calculateTotalsScore(text: text, position: center)
        
        // Noise Score
        scores[.noise] = calculateNoiseScore(text: text, position: center)
        
        // ──────────────────────────────────────────────────────────────
        // DECISION: Select label with highest score
        // ──────────────────────────────────────────────────────────────
        let bestLabel = scores
            .filter { $0.value > 30 } // Minimum confidence threshold
            .max { $0.value < $1.value }?
            .key
        
        return bestLabel ?? .unknown
    }
    
    /// Satıcı anahtar kelimelerini sayar (VKN, LTD, TİCARET vb.)
    private func countSellerKeywords(in text: String) -> Int {
        let keywords = ["VKN", "LTD", "A.Ş", "AŞ", "TİCARET", "TICARET", "SANAYİ", "SANAYI", "MERSIS"]
        return keywords.filter { text.contains($0) }.count
    }
    
    // MARK: - Score Calculation Methods
    
    /// Calculates seller candidate score.
    ///
    /// **Position Bonus:** Top-Left quadrant (y < topThreshold, x < 0.5)
    /// **Content Bonus:** VKN, MERSIS, corporate suffixes
    /// **Multi-Keyword Bonus:** 3+ seller keywords = override position
    /// **Negative Penalty:** Contains buyer signals or cargo keywords
    private func calculateSellerScore(text: String, position: CGPoint, lineCount: Int = 1) -> Double {
        var score: Double = 0
        
        // Position Score: Top-Left quadrant
        if position.y < config.topThreshold && position.x < config.leftThreshold {
            score += 40 // Strong position signal
        } else if position.y < config.topThreshold {
            score += 20 // At least in top region
        }
        
        // Content Score: Seller keywords
        score += calculateContentScore(text: text, signals: sellerSignals)
        
        // Multi-Keyword Boost
        // Eğer 3+ satıcı anahtar kelimesi varsa, konum ne olursa olsun seller olarak işaretle
        let keywordCount = countSellerKeywords(in: text)
        if keywordCount >= 3 {
            score += 50 // Override position with strong content signal
        } else if keywordCount >= 2 {
            score += 25 // Moderate boost for 2 keywords
        }
        
        // Negative Score: Buyer signals present = NOT seller
        let buyerPenalty = calculateContentScore(text: text, signals: buyerSignals)
        if buyerPenalty > 0 {
            score -= buyerPenalty * 1.5 // Strong penalty
        }
        
        // GENEL KURAL: Lojistik firmaları Asla Satıcı Olamaz
        // Bu kural tüm kargo firmaları için geçerlidir.
        let logisticKeywords = ["GÖNDERİ TAŞIYAN", "GONDERI TASIYAN", "TAŞIYAN", "TASIYAN",
                                "KARGO", "LOJİSTİK", "LOJISTIK", "NAKLİYE", "NAKLIYE", "DAĞITIM", "DAGITIM"]
        for keyword in logisticKeywords {
            if text.contains(keyword) {
                return -1000.0 // Kesin Ret
            }
        }
        
        return max(0, score)
    }
    
    /// Calculates buyer candidate score.
    ///
    /// **Position Bonus:** Left column, below seller (y > 0.2, x < 0.5)
    /// **Content Bonus:** SAYIN, ALICI, delivery address keywords
    private func calculateBuyerScore(text: String, position: CGPoint) -> Double {
        var score: Double = 0
        
        // Position Score: Left column, middle region
        if position.x < config.leftThreshold && position.y >= 0.20 && position.y < config.bottomThreshold {
            score += 25
        }
        
        // Content Score: Buyer keywords
        score += calculateContentScore(text: text, signals: buyerSignals)
        
        // "SATICI" kelimesi varsa bu buyer değil seller bloğu
        // Örn: "Satıcı (Merkez): Moonlıfe Mobilya..." → Seller olmalı
        if text.contains("SATICI") && !text.contains("ALICI") {
            score -= 100 // Strong penalty - bu kesinlikle seller
        }
        
        return max(0, score)
    }
    
    /// Calculates meta (invoice details) candidate score.
    ///
    /// **Position Bonus:** Top-Right quadrant (y < 0.3, x > 0.5)
    /// **Content Bonus:** FATURA NO, date/time keywords
    private func calculateMetaScore(text: String, position: CGPoint) -> Double {
        var score: Double = 0
        
        // Position Score: Top-Right quadrant
        if position.y < config.topThreshold && position.x > config.rightThreshold {
            score += 40
        } else if position.x > config.rightThreshold {
            score += 15 // Right side at least
        }
        
        // Content Score: Meta keywords
        score += calculateContentScore(text: text, signals: metaSignals)
        
        return max(0, score)
    }
    
    /// Calculates totals candidate score.
    ///
    /// **Position Bonus:** Bottom-Right quadrant (y > 0.6, x > 0.5)
    /// **Content Bonus:** TOPLAM, KDV, payment keywords
    private func calculateTotalsScore(text: String, position: CGPoint) -> Double {
        var score: Double = 0
        
        // Position Score: Bottom-Right quadrant
        if position.y > config.bottomThreshold && position.x > config.rightThreshold {
            score += 45 // Very strong position signal
        } else if position.y > config.bottomThreshold {
            score += 20 // At least in bottom region
        }
        
        // Content Score: Totals keywords
        score += calculateContentScore(text: text, signals: totalsSignals)
        
        return max(0, score)
    }
    
    /// Calculates noise candidate score.
    ///
    /// **Content-Only:** IBAN, BANKA, QR markers
    /// **** Top margin isolated numbers (Y < 0.10) are noise
    /// No strong position signal (can be anywhere)
    private func calculateNoiseScore(text: String, position: CGPoint? = nil) -> Double {
        var score = calculateContentScore(text: text, signals: noiseSignals)
        
        // Tepe bölgesi izole sayı tespiti
        // Y < 0.10 ve salt sayı ise bu muhtemelen barkod/tracking number
        if let pos = position, pos.y < ExtractionConstants.topMarginNoiseThreshold {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let digitsOnly = trimmedText.filter { $0.isNumber }
            
            // Salt sayı bloğu ve 9+ hane (barkod/tracking formatı)
            if trimmedText == digitsOnly && digitsOnly.count >= 9 {
                score += 100 // Çok yüksek noise skoru
            }
        }
        
        return score
    }
    
    // MARK: - Helper Methods
    
    /// Calculates content score based on keyword presence.
    ///
    /// - Parameters:
    ///   - text: Uppercase text to search
    ///   - signals: Array of (keyword, weight) tuples
    /// - Returns: Sum of weights for matched keywords
    private func calculateContentScore(text: String, signals: [(keyword: String, weight: Double)]) -> Double {
        var score: Double = 0
        for (keyword, weight) in signals {
            if text.contains(keyword) {
                score += weight
            }
        }
        return score
    }
    
    /// Checks if text contains a UUID (ETTN format).
    private func containsUUID(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return uuidRegex.firstMatch(in: text, options: [], range: range) != nil
    }
}

// MARK: - Convenience Extension

extension BlockLabeler {
    /// Labels blocks and returns only those with non-unknown labels.
    ///
    /// - Parameter blocks: Input semantic blocks
    /// - Returns: Filtered array of labeled blocks (unknown removed)
    public func labelAndFilter(_ blocks: [SemanticBlock]) -> [LabeledBlock] {
        return performLabeling(blocks).filter { $0.label != .unknown }
    }
    
    /// Debug method: Prints labeling decisions with scores.
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

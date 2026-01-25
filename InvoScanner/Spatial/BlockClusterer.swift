import Foundation
import CoreGraphics

// MARK: - Blok Kümeleyici

/// OCR kelimelerini mantıksal paragraflara birleştiren motor.
///
/// **Algoritma:**
/// 1. Y-koordinatına göre sıralama (yukarıdan aşağıya).
/// 2. Yakınlık ve hizalamaya göre birleştirme.
/// 3. Sütun sınırlarını koruma.
public struct BlockClusterer {
    
    // MARK: - Yapılandırma
    
    public struct Config {
        /// Maksimum dikey mesafe oranı (satır yüksekliğinin katı)
        public let verticalMergeRatio: CGFloat
        
        /// Aynı satırda birleştirme için maksimum yatay mesafe
        public let horizontalMergeThreshold: CGFloat
        
        /// Hizalama tespiti için tolerans
        public let alignmentThreshold: CGFloat
        
        /// Sol sütun sınırı
        public let leftColumnMaxX: CGFloat
        
        /// Sağ sütun sınırı
        public let rightColumnMinX: CGFloat
        
        /// Sütunlar arası birleşmeyi engelleyen maksimum X mesafesi
        public let maxMergeXDistance: CGFloat
        
        public static let standard = Config(
            verticalMergeRatio: 1.5,
            horizontalMergeThreshold: 0.10,
            alignmentThreshold: 0.05,
            leftColumnMaxX: 0.45,
            rightColumnMinX: 0.55,
            maxMergeXDistance: 0.40
        )
        
        public init(
            verticalMergeRatio: CGFloat = 1.5,
            horizontalMergeThreshold: CGFloat = 0.10,
            alignmentThreshold: CGFloat = 0.05,
            leftColumnMaxX: CGFloat = 0.45,
            rightColumnMinX: CGFloat = 0.55,
            maxMergeXDistance: CGFloat = 0.40
        ) {
            self.verticalMergeRatio = verticalMergeRatio
            self.horizontalMergeThreshold = horizontalMergeThreshold
            self.alignmentThreshold = alignmentThreshold
            self.leftColumnMaxX = leftColumnMaxX
            self.rightColumnMinX = rightColumnMinX
            self.maxMergeXDistance = maxMergeXDistance
        }
    }
    
    private let config: Config
    
    public init(config: Config = .standard) {
        self.config = config
    }
    
    // MARK: - Ana Kümeleme Fonksiyonları
    
    /// Ham metin bloklarını semantik bloklara dönüştürür
    public static func cluster(blocks: [TextBlock]) -> [SemanticBlock] {
        let clusterer = BlockClusterer()
        return clusterer.performClustering(blocks)
    }
    
    /// Kümeleme işlemini gerçekleştirir
    public func performClustering(_ blocks: [TextBlock]) -> [SemanticBlock] {
        guard !blocks.isEmpty else { return [] }
        
        // Adım 1: Y koordinatına göre sırala
        let sortedBlocks = blocks.sorted { $0.frame.minY < $1.frame.minY }
        
        // Adım 2: Başlangıç kümelerini oluştur
        var clusters: [[TextBlock]] = sortedBlocks.map { [$0] }
        
        // Adım 3: İteratif birleştirme geçişi
        var merged = true
        while merged {
            merged = false
            var i = 0
            while i < clusters.count {
                var j = i + 1
                while j < clusters.count {
                    if shouldMergeClusters(clusters[i], clusters[j]) {
                        // Küme j'yi küme i'ye ekle
                        clusters[i].append(contentsOf: clusters[j])
                        clusters.remove(at: j)
                        merged = true
                    } else {
                        j += 1
                    }
                }
                i += 1
            }
        }
        
        // Adım 4: SemanticBlock nesnelerine dönüştür
        return clusters.map { SemanticBlock(children: $0) }
    }
    
    // MARK: - Birleştirme Mantığı
    
    /// İki kümenin birleşip birleşmeyeceğine karar verir
    private func shouldMergeClusters(_ cluster1: [TextBlock], _ cluster2: [TextBlock]) -> Bool {
        for block1 in cluster1 {
            for block2 in cluster2 {
                if shouldMerge(block1: block1, block2: block2) {
                    return true
                }
            }
        }
        return false
    }
    
    /// İki blok arasındaki birleşme kriterlerini kontrol eder
    private func shouldMerge(block1: TextBlock, block2: TextBlock) -> Bool {
        let frame1 = block1.frame
        let frame2 = block2.frame
        
        // KISIT: Sütun Ayrımı
        let xDistance = abs(frame1.midX - frame2.midX)
        if xDistance > config.maxMergeXDistance {
            return false
        }
        
        // Farklı sütunlardaki blokları birleştirme
        let block1Column = determineColumn(frame1.midX)
        let block2Column = determineColumn(frame2.midX)
        if block1Column != block2Column && block1Column != .center && block2Column != .center {
            return false
        }
        
        // DURUM 1: Aynı Satır (Yatay Birleştirme)
        if hasVerticalOverlap(frame1, frame2) {
            let hDistance = horizontalGap(frame1, frame2)
            if hDistance < config.horizontalMergeThreshold && hDistance >= 0 {
                return true
            }
        }
        
        // DURUM 2: Dikey Yakınlık + Hizalama (Paragraf Birleştirme)
        let avgLineHeight = max(frame1.height, frame2.height)
        let vDistance = verticalGap(frame1, frame2)
        let verticalThreshold = avgLineHeight * config.verticalMergeRatio
        
        if vDistance >= 0 && vDistance < verticalThreshold {
            if isAligned(frame1, frame2) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Hizalama Tespiti
    
    /// İki kare çerçevesinin hizalı olup olmadığını kontrol eder (sol, sağ veya merkez)
    private func isAligned(_ frame1: CGRect, _ frame2: CGRect) -> Bool {
        let threshold = config.alignmentThreshold
        
        let leftAligned = abs(frame1.minX - frame2.minX) < threshold
        let rightAligned = abs(frame1.maxX - frame2.maxX) < threshold
        let centerAligned = abs(frame1.midX - frame2.midX) < threshold
        
        return leftAligned || rightAligned || centerAligned
    }
    
    // MARK: - Sütun Tespiti
    
    private enum Column { case left, center, right }
    
    /// Verilen X koordinatına göre sütunu belirler
    private func determineColumn(_ x: CGFloat) -> Column {
        if x < config.leftColumnMaxX {
            return .left
        } else if x > config.rightColumnMinX {
            return .right
        } else {
            return .center
        }
    }
    
    // MARK: - Geometri Yardımcıları
    
    /// Dikey örtüşme kontrolü
    private func hasVerticalOverlap(_ frame1: CGRect, _ frame2: CGRect) -> Bool {
        let yOverlap = min(frame1.maxY, frame2.maxY) - max(frame1.minY, frame2.minY)
        return yOverlap > 0
    }
    
    /// Yatay boşluk hesaplama
    private func horizontalGap(_ frame1: CGRect, _ frame2: CGRect) -> CGFloat {
        let leftFrame = frame1.minX < frame2.minX ? frame1 : frame2
        let rightFrame = frame1.minX < frame2.minX ? frame2 : frame1
        return rightFrame.minX - leftFrame.maxX
    }
    
    /// Dikey boşluk hesaplama
    private func verticalGap(_ frame1: CGRect, _ frame2: CGRect) -> CGFloat {
        let topFrame = frame1.minY < frame2.minY ? frame1 : frame2
        let bottomFrame = frame1.minY < frame2.minY ? frame2 : frame1
        return bottomFrame.minY - topFrame.maxY
    }
}

// MARK: - Kolaylık Eklentisi

extension BlockClusterer {
    /// Blokları seyreltir ve kümeler
    public func cluster(_ blocks: [TextBlock], minTextLength: Int = 1) -> [SemanticBlock] {
        let filtered = blocks.filter { $0.text.count >= minTextLength }
        return performClustering(filtered)
    }
}

import Foundation
import CoreGraphics

// MARK: - Block Clusterer

/// OCR kelimelerini mantıksal paragraflara birleştiren kümeleme motoru.
///
/// **Algoritma:**
/// 1. Girdileri Y-koordinatına göre sırala (yukarıdan aşağı okuma sırası)
/// 2. Yakınlık ve hizalamaya göre blokları birleştir
/// 3. Sütun sınırlarını koru (sütunlar arası birleşmeyi engelle)
///
/// **Eşik Değerleri:**
/// - `verticalMergeRatio`: Aynı paragraf tespiti için 1.5x satır yüksekliği
/// - `horizontalMergeThreshold`: Aynı satırdaki kelimeleri birleştirmek için 0.1 normalize birim
/// - `alignmentThreshold`: Sol/sağ/orta hizalama tespiti için 0.05
/// - `columnSeparator`: Sütunlar arası "ölü bölge" 0.45-0.55
public struct BlockClusterer {
    
    // MARK: - Configuration
    
    public struct Config {
        /// Maximum vertical distance as a ratio of average line height for merging
        /// 1.5x means blocks within 1.5 line heights are considered same paragraph
        public let verticalMergeRatio: CGFloat
        
        /// Maximum horizontal distance for same-line word merging (normalized)
        /// 0.1 = 10% of page width gap is acceptable
        public let horizontalMergeThreshold: CGFloat
        
        /// Alignment tolerance for detecting left/right/center alignment (normalized)
        /// 0.05 = 5% tolerance for alignment detection
        public let alignmentThreshold: CGFloat
        
        /// X-coordinate below which blocks are considered "Left Column"
        public let leftColumnMaxX: CGFloat
        
        /// X-coordinate above which blocks are considered "Right Column"
        public let rightColumnMinX: CGFloat
        
        /// Birleştirme için maksimum X-mesafesi (sütunlar arası birleşmeyi engeller)
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
    
    // MARK: - Ana Kümeleme
    
    /// Ham TextBlock'ları SemanticBlock'lara kümeler.
    public static func cluster(blocks: [TextBlock]) -> [SemanticBlock] {
        let clusterer = BlockClusterer()
        return clusterer.performClustering(blocks)
    }
    
    /// Özel konfigürasyon ile kümeleme
    public func performClustering(_ blocks: [TextBlock]) -> [SemanticBlock] {
        guard !blocks.isEmpty else { return [] }
        
        // Step 1: Sort by Y-coordinate (reading order: top to bottom)
        let sortedBlocks = blocks.sorted { $0.frame.minY < $1.frame.minY }
        
        // Step 2: Initialize clusters (each block starts in its own cluster)
        var clusters: [[TextBlock]] = sortedBlocks.map { [$0] }
        
        // Step 3: Iterative merge pass
        var merged = true
        while merged {
            merged = false
            var i = 0
            while i < clusters.count {
                var j = i + 1
                while j < clusters.count {
                    if shouldMergeClusters(clusters[i], clusters[j]) {
                        // Merge cluster j into cluster i
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
        
        // Step 4: Convert to SemanticBlocks
        return clusters.map { SemanticBlock(children: $0) }
    }
    
    // MARK: - Merge Decision Logic
    
    /// Determines if two clusters should be merged.
    ///
    /// **Merge Conditions (ANY of the following):**
    /// 1. Vertical proximity + Alignment (same paragraph, different lines)
    /// 2. Horizontal proximity + Same line (words on same line)
    ///
    /// **Anti-Merge Conditions (blocks in both clusters):**
    /// - X-distance exceeds maxMergeXDistance (cross-column protection)
    private func shouldMergeClusters(_ cluster1: [TextBlock], _ cluster2: [TextBlock]) -> Bool {
        // Check all block pairs between clusters
        for block1 in cluster1 {
            for block2 in cluster2 {
                if shouldMerge(block1: block1, block2: block2) {
                    return true
                }
            }
        }
        return false
    }
    
    /// Core merge logic for two individual blocks.
    ///
    /// - Parameters:
    ///   - block1: First text block
    ///   - block2: Second text block
    /// - Returns: true if blocks should be in the same semantic block
    private func shouldMerge(block1: TextBlock, block2: TextBlock) -> Bool {
        let frame1 = block1.frame
        let frame2 = block2.frame
        
        // ──────────────────────────────────────────────────────────────
        // CONSTRAINT: Column Separation
        // ──────────────────────────────────────────────────────────────
        // Blocks too far apart horizontally should NEVER merge
        // This prevents "DSM GRUP" from merging with "FATURA NO: 12345"
        let xDistance = abs(frame1.midX - frame2.midX)
        if xDistance > config.maxMergeXDistance {
            return false
        }
        
        // Check if blocks are in different columns
        let block1Column = determineColumn(frame1.midX)
        let block2Column = determineColumn(frame2.midX)
        if block1Column != block2Column && block1Column != .center && block2Column != .center {
            return false // Different columns, don't merge
        }
        
        // ──────────────────────────────────────────────────────────────
        // CASE 1: Same Line (Horizontal Merge)
        // ──────────────────────────────────────────────────────────────
        // Two words on the same line should merge if close enough
        // Example: "D-MARKET" and "TICARET" -> "D-MARKET TICARET"
        if hasVerticalOverlap(frame1, frame2) {
            let hDistance = horizontalGap(frame1, frame2)
            if hDistance < config.horizontalMergeThreshold && hDistance >= 0 {
                return true
            }
        }
        
        // ──────────────────────────────────────────────────────────────
        // CASE 2: Vertical Proximity + Alignment (Paragraph Merge)
        // ──────────────────────────────────────────────────────────────
        // Lines in the same paragraph should merge
        // Requires: Close vertically AND aligned (left, right, or center)
        let avgLineHeight = max(frame1.height, frame2.height)
        let vDistance = verticalGap(frame1, frame2)
        
        // Magic Number: 1.5x line height
        // Rationale: Paragraph spacing is typically 1.0-1.5x line height
        // Single-spaced text: 1.0x, 1.5-spaced: 1.5x, Double-spaced: 2.0x
        let verticalThreshold = avgLineHeight * config.verticalMergeRatio
        
        if vDistance >= 0 && vDistance < verticalThreshold {
            // Check alignment
            if isAligned(frame1, frame2) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Alignment Detection
    
    /// Checks if two frames are aligned (left, right, or center).
    ///
    /// **Alignment Types:**
    /// - Left-aligned: Left edges within tolerance
    /// - Right-aligned: Right edges within tolerance
    /// - Center-aligned: Centers within tolerance
    private func isAligned(_ frame1: CGRect, _ frame2: CGRect) -> Bool {
        let threshold = config.alignmentThreshold
        
        // Left alignment: both blocks start at similar X position
        let leftAligned = abs(frame1.minX - frame2.minX) < threshold
        
        // Right alignment: both blocks end at similar X position
        let rightAligned = abs(frame1.maxX - frame2.maxX) < threshold
        
        // Center alignment: both blocks have similar center X
        let centerAligned = abs(frame1.midX - frame2.midX) < threshold
        
        return leftAligned || rightAligned || centerAligned
    }
    
    // MARK: - Column Detection
    
    private enum Column { case left, center, right }
    
    private func determineColumn(_ x: CGFloat) -> Column {
        if x < config.leftColumnMaxX {
            return .left
        } else if x > config.rightColumnMinX {
            return .right
        } else {
            return .center
        }
    }
    
    // MARK: - Geometry Helpers
    
    /// Checks if two frames overlap vertically (share Y-range).
    private func hasVerticalOverlap(_ frame1: CGRect, _ frame2: CGRect) -> Bool {
        let yOverlap = min(frame1.maxY, frame2.maxY) - max(frame1.minY, frame2.minY)
        return yOverlap > 0
    }
    
    /// Calculates horizontal gap between two frames.
    /// Returns negative if frames overlap horizontally.
    private func horizontalGap(_ frame1: CGRect, _ frame2: CGRect) -> CGFloat {
        let leftFrame = frame1.minX < frame2.minX ? frame1 : frame2
        let rightFrame = frame1.minX < frame2.minX ? frame2 : frame1
        return rightFrame.minX - leftFrame.maxX
    }
    
    /// Calculates vertical gap between two frames.
    /// Returns negative if frames overlap vertically.
    private func verticalGap(_ frame1: CGRect, _ frame2: CGRect) -> CGFloat {
        let topFrame = frame1.minY < frame2.minY ? frame1 : frame2
        let bottomFrame = frame1.minY < frame2.minY ? frame2 : frame1
        return bottomFrame.minY - topFrame.maxY
    }
}

// MARK: - Convenience Extension

extension BlockClusterer {
    /// Clusters and optionally filters blocks by minimum text length.
    ///
    /// - Parameters:
    ///   - blocks: Input text blocks
    ///   - minTextLength: Minimum text length to include (filters noise)
    /// - Returns: Filtered and clustered semantic blocks
    public func cluster(_ blocks: [TextBlock], minTextLength: Int = 1) -> [SemanticBlock] {
        let filtered = blocks.filter { $0.text.count >= minTextLength }
        return performClustering(filtered)
    }
}

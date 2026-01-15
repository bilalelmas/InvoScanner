import Foundation
import CoreGraphics

// MARK: - Spatial Models

/// 2D blok bazlı belge analizi için temel veri yapıları

// MARK: - TextBlock

/// Ham OCR çıktısı temsili.
/// Metin içeriği ve normalize edilmiş sınırlayıcı kutu (0..1 koordinat uzayı).
///
/// - Not: Koordinat sistemi:
///   - Orijin (0,0) SOL-ÜST köşede
///   - Y aşağı doğru artar (0 = üst, 1 = alt)
///   - X sağa doğru artar (0 = sol, 1 = sağ)
public struct TextBlock: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let text: String
    public let frame: CGRect  // Normalized coordinates (0..1)
    
    public init(id: UUID = UUID(), text: String, frame: CGRect) {
        self.id = id
        self.text = text
        self.frame = frame
    }
    
    // MARK: Convenience Properties
    
    /// Center point of the text block
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
    
    /// Average line height estimation (for single-line blocks)
    public var estimatedLineHeight: CGFloat {
        frame.height
    }
    
    // MARK: Geometry Helpers
    
    /// Checks if this block is on approximately the same line as another.
    /// Uses Y-midpoint comparison with a configurable threshold.
    ///
    /// - Parameters:
    ///   - other: The other block to compare
    ///   - threshold: Maximum Y-midpoint difference (default: 2% of page height)
    /// - Returns: true if blocks are on the same horizontal line
    public func isSameLine(as other: TextBlock, threshold: CGFloat = 0.02) -> Bool {
        return abs(self.frame.midY - other.frame.midY) < threshold
    }
    
    /// Calculates horizontal distance to another block (gap between edges).
    /// Returns negative if blocks overlap horizontally.
    ///
    /// - Parameter other: The other block
    /// - Returns: Distance between right edge of leftmost block and left edge of rightmost block
    public func horizontalDistance(to other: TextBlock) -> CGFloat {
        let leftBlock = self.frame.minX < other.frame.minX ? self : other
        let rightBlock = self.frame.minX < other.frame.minX ? other : self
        return rightBlock.frame.minX - leftBlock.frame.maxX
    }
    
    /// Calculates vertical distance to another block (gap between edges).
    /// Returns negative if blocks overlap vertically.
    ///
    /// - Parameter other: The other block
    /// - Returns: Distance between bottom edge of upper block and top edge of lower block
    public func verticalDistance(to other: TextBlock) -> CGFloat {
        let upperBlock = self.frame.minY < other.frame.minY ? self : other
        let lowerBlock = self.frame.minY < other.frame.minY ? other : self
        return lowerBlock.frame.minY - upperBlock.frame.maxY
    }
}

// MARK: - SemanticBlock

/// Clustered paragraph: Represents a logical grouping of TextBlocks.
/// Used after spatial clustering to represent coherent text regions.
///
/// - Important: The `children` array should be sorted by reading order
///   (top-to-bottom, left-to-right) for proper text reconstruction.
public struct SemanticBlock: Identifiable, Equatable {
    public let id: UUID
    public var children: [TextBlock]
    public var label: BlockLabel
    
    public init(id: UUID = UUID(), children: [TextBlock], label: BlockLabel = .unknown) {
        self.id = id
        self.children = children
        self.label = label
    }
    
    // MARK: Computed Properties
    
    /// The union (bounding box) of all child frames.
    /// Uses CGRect.union for precise geometry calculation.
    public var frame: CGRect {
        guard let first = children.first else { return .zero }
        
        return children.dropFirst().reduce(first.frame) { result, block in
            result.union(block.frame)
        }
    }
    
    /// Center point of the semantic block's bounding box.
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
    
    /// Joined text of all children.
    /// - Children on the same line are joined with spaces
    /// - Children on different lines are joined with newlines
    ///
    /// **Algorithm:**
    /// 1. Sort children by Y-coordinate (top to bottom)
    /// 2. Group children that are on the same line
    /// 3. Within each line, sort by X-coordinate (left to right)
    /// 4. Join with spaces (same line) and newlines (different lines)
    public var text: String {
        guard !children.isEmpty else { return "" }
        
        // Sort by Y first
        let sortedByY = children.sorted { $0.frame.minY < $1.frame.minY }
        
        // Group into lines
        var lines: [[TextBlock]] = []
        var currentLine: [TextBlock] = []
        
        // Magic Number: 1% of page height for precise line separation
        // 0.02 was causing line mixing, 0.01 provides sharper separation
        let lineThreshold: CGFloat = 0.01
        
        for block in sortedByY {
            if let lastInLine = currentLine.last {
                let yDiff = abs(block.frame.midY - lastInLine.frame.midY)
                if yDiff < lineThreshold {
                    currentLine.append(block)
                } else {
                    lines.append(currentLine)
                    currentLine = [block]
                }
            } else {
                currentLine.append(block)
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        // Sort each line by X, then join
        return lines
            .map { line in
                line.sorted { $0.frame.minX < $1.frame.minX }
                    .map { $0.text }
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }
    
    /// Average line height within this semantic block.
    /// Used for merge threshold calculations.
    public var averageLineHeight: CGFloat {
        guard !children.isEmpty else { return 0.02 } // Default fallback
        let totalHeight = children.reduce(0) { $0 + $1.frame.height }
        return totalHeight / CGFloat(children.count)
    }
}

// MARK: - BlockLabel

/// Semantic labels for document regions.
/// Each label represents a specific functional area of an invoice.
///
/// **Label Priority for Conflict Resolution:**
/// - ETTN has highest priority (unique identifier)
/// - Seller/Buyer/Meta have medium priority (key information)
/// - Totals has medium-high priority (financial data)
/// - Noise has low priority (can be safely ignored)
/// - Unknown is default fallback
public enum BlockLabel: String, CaseIterable, Equatable {
    
    /// Seller information block (Top-Left quadrant)
    /// Contains: Company name, VKN, MERSIS, Tax office
    case seller = "SELLER"
    
    /// Buyer information block (Left column, below seller)
    /// Contains: "SAYIN", customer name, delivery address
    case buyer = "BUYER"
    
    /// Invoice metadata block (Top-Right quadrant)
    /// Contains: Invoice number, date, time, scenario
    case meta = "META"
    
    /// Totals block (Bottom-Right quadrant)
    /// Contains: Subtotal, VAT, Grand total, Payable amount
    case totals = "TOTALS"
    
    /// ETTN block (can be anywhere, usually isolated)
    /// Contains: UUID format (8-4-4-4-12)
    case ettn = "ETTN"
    
    /// Noise block (logos, QR codes, bank info)
    /// Contains: IBAN, bank name, MERSIS NO (isolated lines)
    case noise = "NOISE"
    
    /// Content/Table block (center region)
    /// Contains: Product/service list, item details
    case content = "CONTENT"
    
    /// Unclassified block (default)
    case unknown = "UNKNOWN"
    
    // MARK: Properties
    
    /// Turkish description for UI display
    public var description: String {
        switch self {
        case .seller: return "Satıcı Bilgileri"
        case .buyer: return "Alıcı Bilgileri"
        case .meta: return "Fatura Meta Verileri"
        case .totals: return "Toplam Tutarlar"
        case .ettn: return "ETTN (Benzersiz Kimlik)"
        case .noise: return "Gürültü (Logo/QR/Banka)"
        case .content: return "Mal/Hizmet İçeriği"
        case .unknown: return "Sınıflandırılmamış"
        }
    }
    
    /// Expected vertical position priority (lower = higher on page)
    /// Used for conflict resolution when multiple blocks compete
    public var expectedYPriority: Int {
        switch self {
        case .seller: return 1
        case .meta: return 1
        case .buyer: return 2
        case .content: return 3
        case .ettn: return 4
        case .totals: return 5
        case .noise: return 6
        case .unknown: return 99
        }
    }
    
    /// Confidence weight for scoring system
    /// Higher weight = more important for final extraction
    public var confidenceWeight: Double {
        switch self {
        case .ettn: return 1.0     // Critical - unique identifier
        case .totals: return 0.9   // High - financial data
        case .seller: return 0.8   // High - key party
        case .meta: return 0.7     // Medium - invoice details
        case .buyer: return 0.6    // Medium - customer info
        case .content: return 0.3  // Low - supporting data
        case .noise: return 0.0    // Ignore
        case .unknown: return 0.1  // Needs investigation
        }
    }
}

// MARK: - LabeledBlock (Convenience Alias)

/// Type alias for a SemanticBlock with an assigned label.
/// Used in the output of BlockLabeler for clarity.
public typealias LabeledBlock = SemanticBlock

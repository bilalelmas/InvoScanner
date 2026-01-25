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
    
    // MARK: Yardımcı Özellikler
    
    /// Bloğun merkez noktası
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
    
    /// Tahmini satır yüksekliği (tek satırlık bloklar için)
    public var estimatedLineHeight: CGFloat {
        frame.height
    }
    
    // MARK: Geometri Yardımcıları
    
    /// Bu bloğun diğeriyle aynı satırda olup olmadığını kontrol eder
    /// - Parameters:
    ///   - other: Karşılaştırılacak diğer blok
    ///   - threshold: Maksimum Y farkı (varsayılan: sayfa yüksekliğinin %2'si)
    /// - Returns: Bloklar aynı yatay satırdaysa true
    public func isSameLine(as other: TextBlock, threshold: CGFloat = 0.02) -> Bool {
        return abs(self.frame.midY - other.frame.midY) < threshold
    }
    
    /// Diğer bloğa olan yatay mesafeyi hesaplar (kenarlar arası boşluk)
    /// - Parameter other: Diğer blok
    /// - Returns: En soldaki bloğun sağ kenarı ile en sağdakinin sol kenarı arası mesafe
    public func horizontalDistance(to other: TextBlock) -> CGFloat {
        let leftBlock = self.frame.minX < other.frame.minX ? self : other
        let rightBlock = self.frame.minX < other.frame.minX ? other : self
        return rightBlock.frame.minX - leftBlock.frame.maxX
    }
    
/// Diğer bloğa olan dikey mesafeyi hesaplar (kenarlar arası boşluk)
    /// - Parameter other: Diğer blok
    /// - Returns: Üst bloğun alt kenarı ile alt bloğun üst kenarı arası mesafe
    public func verticalDistance(to other: TextBlock) -> CGFloat {
        let upperBlock = self.frame.minY < other.frame.minY ? self : other
        let lowerBlock = self.frame.minY < other.frame.minY ? other : self
        return lowerBlock.frame.minY - upperBlock.frame.maxY
    }
}

// MARK: - SemanticBlock

/// Kümelenmiş paragraf: TextBlock'ların mantıksal gruplandırılması
/// Uzamsal kümeleme sonrası tutarlı metin bölgelerini temsil eder
///
/// - Önemli: `children` dizisi okuma sırasına göre sıralı olmalıdır
///   (yukarıdan aşağıya, soldan sağa)
public struct SemanticBlock: Identifiable, Equatable {
    public let id: UUID
    public var children: [TextBlock]
    public var label: BlockLabel
    
    public init(id: UUID = UUID(), children: [TextBlock], label: BlockLabel = .unknown) {
        self.id = id
        self.children = children
        self.label = label
    }
    
    // MARK: Hesaplanan Özellikler
    
    /// Tüm çocuk çerçevelerin birleşimi (bounding box)
    public var frame: CGRect {
        guard let first = children.first else { return .zero }
        
        return children.dropFirst().reduce(first.frame) { result, block in
            result.union(block.frame)
        }
    }
    
    /// Semantik bloğun merkez noktası
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
    
    /// Tüm çocukların birleştirilmiş metni
    /// - Aynı satırdakiler boşlukla, farklı satırdakiler alt satır karakteriyle birleşir
    ///
    /// **Algoritma:**
    /// 1. Y koordinatına göre sıralama
    /// 2. Aynı satırdaki blokları gruplama
    /// 3. Satır içi X koordinatına göre sıralama
    /// 4. Boşluk ve alt satır karakteriyle birleştirme
    public var text: String {
        guard !children.isEmpty else { return "" }
        
        // Önce Y koordinatına göre sırala
        let sortedByY = children.sorted { $0.frame.minY < $1.frame.minY }
        
        // Satırlara grupla
        var lines: [[TextBlock]] = []
        var currentLine: [TextBlock] = []
        
        // Hassas satır ayrımı için eşik değer (Sayfa yüksekliğinin %1'i)
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
        
        // Her satırı X'e göre sırala ve birleştir
        return lines
            .map { line in
                line.sorted { $0.frame.minX < $1.frame.minX }
                    .map { $0.text }
                    .joined(separator: " ")
            }
            .joined(separator: "\n")
    }
    
    /// Bu semantik blok içindeki ortalama satır yüksekliği
    public var averageLineHeight: CGFloat {
        guard !children.isEmpty else { return 0.02 }
        let totalHeight = children.reduce(0) { $0 + $1.frame.height }
        return totalHeight / CGFloat(children.count)
    }
}

// MARK: - Blok Etiketi

/// Belge bölgeleri için semantik etiketler
/// Her etiket, faturanın belirli bir fonksiyonel alanını temsil eder
///
/// **Öncelik Sıralaması:**
/// - ETTN: En yüksek (benzersiz kimlik)
/// - Satıcı/Alıcı/Meta: Orta (ana bilgiler)
/// - Toplamlar: Orta-yüksek (finansal veriler)
/// - Noise: Düşük (yoksayılabilir)
/// - Unknown: Varsayılan (tanımlanamayan)
public enum BlockLabel: String, CaseIterable, Equatable {
    /// Satıcı bilgileri (Sol-üst bölge)
    case seller = "SELLER"
    
    /// Alıcı bilgileri (Sol sütun, satıcı altı)
    case buyer = "BUYER"
    
    /// Fatura meta verileri (Sağ-üst bölge)
    case meta = "META"
    
    /// Toplamlar bloğu (Sağ-alt bölge)
    case totals = "TOTALS"
    
    /// ETTN bloğu (Her yerde olabilir)
    case ettn = "ETTN"
    
    /// Gürültü bloğu (Logo, QR, banka bilgisi)
    case noise = "NOISE"
    
    /// İçerik/Tablo bloğu (Orta bölge)
    case content = "CONTENT"
    
    /// Sınıflandırılmamış (Varsayılan)
    case unknown = "UNKNOWN"
    
    // MARK: Özellikler
    
    /// Kullanıcı arayüzü için Türkçe açıklama
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
    
    /// Beklenen dikey konum önceliği (düşük = daha yukarıda)
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
    
    /// Karar sistemi için güven ağırlığı
    public var confidenceWeight: Double {
        switch self {
        case .ettn: return 1.0     // Kritik - benzersiz kimlik
        case .totals: return 0.9   // Yüksek - finansal veri
        case .seller: return 0.8   // Yüksek - ana taraf
        case .meta: return 0.7     // Orta - fatura detayları
        case .buyer: return 0.6    // Orta - müşteri bilgisi
        case .content: return 0.3  // Düşük - destekleyici veri
        case .noise: return 0.0    // Yoksay
        case .unknown: return 0.1  // İnceleme gerektirir
        }
    }
}

// MARK: - LabeledBlock (Takma Ad)

/// Etiketlenmiş bir SemanticBlock için kullanılan tip takma adı.
public typealias LabeledBlock = SemanticBlock

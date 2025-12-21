import Foundation

/// Metin bloklarından belirli bir veri tipini ayıklamak için strateji tanımlayan protokol
protocol ExtractionStrategy {
    associatedtype ResultType
    
    /// Verilen metin bloklarından veri ayıklar
    /// - Parameter blocks: Belgeden ayıklanan metin blokları listesi
    /// - Returns: Ayıklanan sonuç veya bulunamazsa nil
    func extract(from blocks: [TextBlock]) -> ResultType?
}

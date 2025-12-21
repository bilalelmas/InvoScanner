import Foundation

/// Ayıklanan nihai fatura verisini temsil eder
struct Invoice: Identifiable, Equatable {
    let id = UUID()
    var ettn: UUID?
    var date: Date?
    var totalAmount: Decimal?
    var supplierName: String?
    
    // Ayıklama işlemi için kullanılan ham metin blokları (hata ayıklama/doğrulama amaçlı)
    var rawBlocks: [TextBlock] = []
}

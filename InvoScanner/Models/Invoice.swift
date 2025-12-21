import Foundation

/// Ayıklanan nihai fatura verisini temsil eder
struct Invoice: Identifiable, Equatable {
    let id = UUID()
    var ettn: UUID?
    var invoiceNumber: String? // Yeni alan
    var date: Date?
    var totalAmount: Decimal?
    var supplierName: String?
    
    // Ayıklama işlemi için kullanılan ham metin blokları (hata ayıklama/doğrulama amaçlı)
    var rawBlocks: [TextBlock] = []
    
    // Güven Skoru (0.0 - 1.0)
    var confidenceScore: Double {
        var score = 0.0
        if ettn != nil { score += 0.40 }
        if invoiceNumber != nil { score += 0.20 }
        if totalAmount != nil { score += 0.20 }
        if supplierName != nil { score += 0.20 }
        return min(score, 1.0)
    }
    
    // Otomatik Onay Eşiği
    var isAutoAccepted: Bool {
        return confidenceScore >= 0.70
    }
}

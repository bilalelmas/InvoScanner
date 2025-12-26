import Foundation

/// Ayıklanan nihai fatura verisini temsil eder
struct Invoice: Identifiable, Equatable {
    let id = UUID()
    var ettn: UUID?
    var invoiceNumber: String?
    var date: Date?
    var totalAmount: Decimal?
    var supplierName: String?
    
    // V5.1: Tutar Doğrulama ("Yalnız..." kontrolü)
    var isAmountVerified: Bool?
    var amountConfidence: Double?
    
    // V5.1: Gelişmiş Güven Skoru (0.0 - 1.0)
    var confidenceScore: Double {
        var score = 0.0
        
        // Temel alan puanları
        if ettn != nil { score += 0.20 }
        if date != nil { score += 0.15 }
        if totalAmount != nil { score += 0.25 }
        if supplierName != nil { score += 0.20 }
        
        // V5.1: Tutar doğrulama bonusu
        if isAmountVerified == true {
            score += 0.20
        } else if let confidence = amountConfidence, confidence > 0.5 {
            score += 0.10
        }
        
        return min(score, 1.0)
    }
    
    // Otomatik Onay Eşiği
    var isAutoAccepted: Bool {
        return confidenceScore >= 0.70
    }
    
    // MARK: - V5 Convenience Initializer
    
    /// SpatialParser sonucundan Invoice oluşturur
    init(from result: SpatialParser.ParsedInvoice) {
        if let ettnStr = result.ettn {
            self.ettn = UUID(uuidString: ettnStr)
        }
        self.invoiceNumber = result.invoiceNumber
        self.date = result.date
        self.totalAmount = result.totalAmount
        self.supplierName = result.supplier
        
        // Tutar doğrulama
        if let verification = result.amountVerification {
            self.isAmountVerified = verification.isMatch
            self.amountConfidence = verification.confidence
        }
    }
    
    // Default initializer
    init() {}
}


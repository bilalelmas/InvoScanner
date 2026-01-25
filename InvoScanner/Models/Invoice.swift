import Foundation

/// Ayıklanan fatura verisi
struct Invoice: Identifiable, Equatable {
    let id = UUID()
    var ettn: UUID?
    var invoiceNumber: String?
    var date: Date?
    var totalAmount: Decimal?
    var supplierName: String?
    
    /// Doğrulama durumu
    var isAmountVerified: Bool?
    var amountConfidence: Double?
    
    /// Güven skoru
    var confidenceScore: Double {
        var score = 0.0
        
        /// Alan bazlı puanlama
        if ettn != nil { score += 0.20 }
        if date != nil { score += 0.15 }
        if totalAmount != nil { score += 0.25 }
        if supplierName != nil { score += 0.20 }
        
        /// Doğrulama bonusu
        if isAmountVerified == true {
            score += 0.20
        } else if let confidence = amountConfidence, confidence > 0.5 {
            score += 0.10
        }
        
        return min(score, 1.0)
    }
    
    /// Otomatik onay kontrolü
    var isAutoAccepted: Bool {
        return confidenceScore >= 0.70
    }
    
    // MARK: - Başlatıcılar
    
    /// Parser sonucundan oluşturur
    init(from result: SpatialParser.ParsedInvoice) {
        if let ettnStr = result.ettn {
            self.ettn = UUID(uuidString: ettnStr)
        }
        self.invoiceNumber = result.invoiceNumber
        self.date = result.date
        self.totalAmount = result.totalAmount
        self.supplierName = result.supplier
        
        /// Doğrulama süreci
        if let verification = result.amountVerification {
            self.isAmountVerified = verification.isMatch
            self.amountConfidence = verification.confidence
        }
    }
    
    /// Varsayılan başlatıcı
    init() {}
}

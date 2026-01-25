import Foundation
import SwiftData
import UIKit

/// Kalıcı fatura modeli
/// Hibrit depolama (Data + Disk)
@Model
final class SavedInvoice {
    
    // MARK: - Kimlik
    
    /// ID
    @Attribute(.unique) var id: UUID
    
    // MARK: - Veri
    
    /// Satıcı adı
    var supplierName: String?
    
    /// Tutar
    var totalAmount: Decimal?
    
    /// Tarih
    var date: Date?
    
    /// ETTN (UUID string)
    var ettn: String?
    
    /// Fatura No
    var invoiceNumber: String?
    
    // MARK: - Dosya Referansı
    
    /// Görsel dosya adı
    /// Veritabanı dışı saklama (FileManager)
    var imageFileName: String?
    
    // MARK: - Meta Veri
    
    /// Oluşturulma tarihi
    var createdAt: Date
    
    /// Otomatik onay durumu
    var isAutoAccepted: Bool
    
    // MARK: - Geçici Veri
    
    /// Önbellekteki görsel
    @Transient var cachedImage: UIImage?
    
    // MARK: - Başlatıcılar
    
    /// Varsayılan başlatıcı
    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.isAutoAccepted = false
    }
    
    /// Invoice nesnesinden oluşturur
    convenience init(from invoice: Invoice, imageFileName: String?) {
        self.init()
        
        self.supplierName = invoice.supplierName
        self.totalAmount = invoice.totalAmount
        self.date = invoice.date
        self.ettn = invoice.ettn?.uuidString
        self.invoiceNumber = invoice.invoiceNumber
        self.imageFileName = imageFileName
        self.isAutoAccepted = invoice.isAutoAccepted
    }
    
    /// Tam başlatıcı
    convenience init(
        id: UUID = UUID(),
        supplierName: String? = nil,
        totalAmount: Decimal? = nil,
        date: Date? = nil,
        ettn: String? = nil,
        invoiceNumber: String? = nil,
        imageFileName: String? = nil,
        isAutoAccepted: Bool = false
    ) {
        self.init()
        self.id = id
        self.supplierName = supplierName
        self.totalAmount = totalAmount
        self.date = date
        self.ettn = ettn
        self.invoiceNumber = invoiceNumber
        self.imageFileName = imageFileName
        self.isAutoAccepted = isAutoAccepted
    }
}

// MARK: - Dönüşüm

extension SavedInvoice {
    /// Invoice nesnesine dönüştürür
    func toInvoice() -> Invoice {
        var invoice = Invoice()
        invoice.supplierName = self.supplierName
        invoice.totalAmount = self.totalAmount
        invoice.date = self.date
        invoice.invoiceNumber = self.invoiceNumber
        
        if let ettnString = self.ettn {
            invoice.ettn = UUID(uuidString: ettnString)
        }
        
        return invoice
    }
}

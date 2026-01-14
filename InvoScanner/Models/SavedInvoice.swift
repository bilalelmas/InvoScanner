import Foundation
import SwiftData
import UIKit

/// Kalıcı olarak saklanan fatura verisi
/// - Hibrit Depolama: Metadata SwiftData'da, görsel FileManager'da
@Model
final class SavedInvoice {
    
    // MARK: - Primary Key
    
    /// Benzersiz tanımlayıcı
    @Attribute(.unique) var id: UUID
    
    // MARK: - Invoice Data
    
    /// Satıcı/Tedarikçi adı
    var supplierName: String?
    
    /// Toplam tutar (TRY)
    var totalAmount: Decimal?
    
    /// Fatura tarihi
    var date: Date?
    
    /// ETTN (Elektronik Fatura Takip Numarası) - UUID olarak string saklanır
    var ettn: String?
    
    /// Fatura numarası
    var invoiceNumber: String?
    
    // MARK: - Hybrid Storage Reference
    
    /// Disk'teki görsel dosyasının adı (e.g., "uuid.jpg")
    /// - Note: Görsel veritabanında saklanmaz, performans için FileManager kullanılır
    var imageFileName: String?
    
    // MARK: - Metadata
    
    /// Kayıt oluşturulma tarihi
    var createdAt: Date
    
    /// Otomatik onay durumu (güven skoru >= 0.70)
    var isAutoAccepted: Bool
    
    // MARK: - Computed (Transient, not stored)
    
    /// Disk'ten yüklenen görsel (lazy loading)
    @Transient var cachedImage: UIImage?
    
    // MARK: - Initializers
    
    /// Default initializer (SwiftData için gerekli)
    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.isAutoAccepted = false
    }
    
    /// Convenience initializer - Geçici Invoice struct'ından oluşturur
    /// - Parameters:
    ///   - invoice: SpatialParser'dan gelen geçici fatura verisi
    ///   - imageFileName: Disk'e kaydedilen görsel dosyasının adı
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
    
    /// Full initializer
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

// MARK: - Conversion to Invoice

extension SavedInvoice {
    /// SavedInvoice'ı geçici Invoice struct'ına çevirir
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

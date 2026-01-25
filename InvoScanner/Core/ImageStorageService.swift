import Foundation
import UIKit

/// Görsel dosya yönetim servisi
struct ImageStorageService {
    
    // MARK: - Paylaşılan Örnek
    
    static let shared = ImageStorageService()
    
    // MARK: - Yapılandırma
    
    /// JPEG sıkıştırma kalitesi
    private let compressionQuality: CGFloat = 0.8
    
    /// Uygulama doküman dizini
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Fatura görselleri dizini
    private var invoiceImagesDirectory: URL {
        documentsDirectory.appendingPathComponent("InvoiceImages", isDirectory: true)
    }
    
    // MARK: - Başlatıcı
    
    private init() {
        createDirectoryIfNeeded()
    }
    
    /// Gerekli dizini oluşturur
    private func createDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: invoiceImagesDirectory.path) {
            try? fileManager.createDirectory(at: invoiceImagesDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Genel Fonksiyonlar
    
    /// Görseli diske kaydeder
    func save(image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        
        let fileName = "\(id.uuidString).jpg"
        let fileURL = invoiceImagesDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }
    
    /// Diskten görsel yükler
    func load(fileName: String) -> UIImage? {
        let fileURL = invoiceImagesDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    /// Diskten görsel siler
    @discardableResult
    func delete(fileName: String) -> Bool {
        let fileURL = invoiceImagesDirectory.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
    
    /// Toplam disk kullanımını hesaplar (Byte)
    func calculateTotalSize() -> Int64 {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: invoiceImagesDirectory.path) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for file in files {
            let filePath = invoiceImagesDirectory.appendingPathComponent(file).path
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    /// Formatlanmış toplam boyut (Örn: 1.2 MB)
    func formattedTotalSize() -> String {
        let bytes = calculateTotalSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

import Foundation
import UIKit

/// Görsel dosya işlemlerini yöneten servis
/// - Hibrit Depolama Stratejisi: Görseller veritabanında değil disk'te saklanır
/// - Avantaj: Veritabanı şişmez, lazy loading mümkün, performans korunur
struct ImageStorageService {
    
    // MARK: - Singleton
    
    static let shared = ImageStorageService()
    
    // MARK: - Configuration
    
    /// JPEG sıkıştırma kalitesi (0.0 - 1.0)
    private let compressionQuality: CGFloat = 0.8
    
    /// Dosyaların saklanacağı dizin
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Fatura görselleri için alt dizin
    private var invoiceImagesDirectory: URL {
        documentsDirectory.appendingPathComponent("InvoiceImages", isDirectory: true)
    }
    
    // MARK: - Init
    
    private init() {
        createDirectoryIfNeeded()
    }
    
    /// Alt dizini oluşturur
    private func createDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: invoiceImagesDirectory.path) {
            try? fileManager.createDirectory(at: invoiceImagesDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Public API
    
    /// Görseli disk'e kaydeder
    /// - Parameters:
    ///   - image: Kaydedilecek UIImage
    ///   - id: Benzersiz tanımlayıcı (dosya adı için kullanılır)
    /// - Returns: Kaydedilen dosyanın adı veya nil (hata durumunda)
    func save(image: UIImage, id: UUID) -> String? {
        // JPEG'e dönüştür
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            print("ImageStorageService: JPEG dönüşümü başarısız")
            return nil
        }
        
        // Dosya yolunu oluştur
        let fileName = "\(id.uuidString).jpg"
        let fileURL = invoiceImagesDirectory.appendingPathComponent(fileName)
        
        // Disk'e yaz
        do {
            try data.write(to: fileURL)
            print("ImageStorageService: Görsel kaydedildi - \(fileName)")
            return fileName
        } catch {
            print("ImageStorageService: Kayıt hatası - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Disk'ten görsel yükler
    /// - Parameter fileName: Dosya adı (e.g., "uuid.jpg")
    /// - Returns: Yüklenen UIImage veya nil
    func load(fileName: String) -> UIImage? {
        let fileURL = invoiceImagesDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ImageStorageService: Dosya bulunamadı - \(fileName)")
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            print("ImageStorageService: Görsel yüklenemedi - \(fileName)")
            return nil
        }
        
        return image
    }
    
    /// Disk'ten görsel siler
    /// - Parameter fileName: Silinecek dosya adı
    /// - Returns: Silme işlemi başarılı mı
    @discardableResult
    func delete(fileName: String) -> Bool {
        let fileURL = invoiceImagesDirectory.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("ImageStorageService: Dosya silindi - \(fileName)")
            return true
        } catch {
            print("ImageStorageService: Silme hatası - \(error.localizedDescription)")
            return false
        }
    }
    
    /// Tüm faturaların toplam disk kullanımını hesaplar
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
    
    /// Formatlı disk kullanımı string'i
    func formattedTotalSize() -> String {
        let bytes = calculateTotalSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

import Foundation
import UIKit
import PDFKit
import Vision
import PhotosUI
import SwiftUI

// MARK: - Input Providing Protocol

/// Tüm girdi kaynaklarını (PDF, Kamera, Galeri) normalize eden protokol
/// - Amaç: Farklı girdi türlerinden tutarlı `[TextBlock]` çıktısı üretmek
protocol InputProviding {
    /// Girdiyi işleyerek metin bloklarına dönüştürür
    func process() async throws -> [TextBlock]
}

// MARK: - Input Source Enum

/// Desteklenen girdi kaynakları
enum InputSource {
    case pdf(URL)
    case image(UIImage)
    case camera // VNDocumentCameraViewController tarafından handle edilir
}

// MARK: - Input Manager Errors

/// Input işleme hataları
enum InputError: LocalizedError {
    case invalidPDF
    case emptyImage
    case ocrFailed
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "PDF dosyası okunamadı veya geçersiz."
        case .emptyImage:
            return "Görsel işlenemedi veya boş."
        case .ocrFailed:
            return "OCR işlemi başarısız oldu."
        case .processingFailed(let reason):
            return "İşleme hatası: \(reason)"
        }
    }
}

// MARK: - PDF Input Provider

/// Native PDF dosyalarından metin çıkarır
/// - Öncelik: PDFKit (Text Layer), Fallback: Vision OCR
/// - Security-Scoped Resource erişimini yönetir (Document Picker'dan gelen dosyalar için)
struct PDFInputProvider: InputProviding {
    let url: URL
    
    func process() async throws -> [TextBlock] {
        // Security-Scoped Resource erişimini başlat
        // Document Picker'dan seçilen dosyalar sandbox dışında olabilir
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        
        // Erişim başladıysa, işlem bittiğinde mutlaka durdur
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            print("PDFInputProvider: PDF açılamadı - URL: \(url.lastPathComponent)")
            throw InputError.invalidPDF
        }
        
        print("PDFInputProvider: PDF başarıyla açıldı - \(document.pageCount) sayfa")
        
        // Adım 1: PDFKit ile doğrudan metin denemesi
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        let cleanText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Yeterli metin varsa satırlara böl ve yapay koordinat ata
        if cleanText.count > 50 {
            print("PDFInputProvider: PDFKit ile \(cleanText.count) karakter alındı.")
            
            // V5 FIX: Metni satırlara böl ve yapay koordinat ata
            // Bu sayede SpatialParser spatial analiz yapabilir
            let blocks = convertTextToBlocks(cleanText)
            print("PDFInputProvider: \(blocks.count) satır/blok oluşturuldu")
            return blocks
        }
        
        // Adım 2: Yetersizse Vision OCR
        print("PDFInputProvider: PDFKit yetersiz, Vision OCR devreye giriyor...")
        guard let page = document.page(at: 0) else {
            throw InputError.invalidPDF
        }
        
        let image = renderPageToImage(page)
        return try await ImageInputProvider(image: image).process()
    }
    
    // MARK: - Text to Blocks Conversion
    
    /// PDFKit metnini satırlara bölerek yapay koordinatlarla TextBlock'lara çevirir
    /// - NOT: e-Arşiv faturaları genellikle iki kolonlu yapıdadır:
    ///   - Sol kolon: Satıcı bilgileri (y < 0.3), Alıcı bilgileri (y 0.3-0.6)
    ///   - Sağ kolon: Fatura meta (y < 0.3), Toplamlar (y > 0.6)
    /// - Heuristic olarak bazı anahtar kelimeler sağ kolona yerleştirilir
    private func convertTextToBlocks(_ text: String) -> [TextBlock] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return [] }
        
        var blocks: [TextBlock] = []
        let lineHeight: CGFloat = 0.02  // Her satır ~%2 yükseklik
        let lineSpacing: CGFloat = 0.01 // Satırlar arası boşluk
        
        // Sağ kolon anahtar kelimeleri
        let rightColumnKeywords = [
            "FATURA NO", "BELGE NO", "TARIH", "TARİH", "DÜZENLEME", "DUZENLEME",
            "TOPLAM", "KDV", "MATRAH", "ODENECEK", "ÖDENECEK", "SENARYO", 
            "FATURA TİPİ", "FATURA TIPI", "SAAT"
        ]
        
        // Alt bölge anahtar kelimeleri (genellikle toplamlar veya footer)
        let bottomKeywords = [
            "GENEL TOPLAM", "ÖDENECEK TUTAR", "YALNIZ", "IBAN", "BANKA",
            "HESAP NO", "ETTN"
        ]
        
        var currentY: CGFloat = 0.05
        
        for line in lines {
            let upperLine = line.uppercased()
            
            // X pozisyonu belirle (heuristic)
            var xPosition: CGFloat = 0.1  // Default: Sol kolon
            
            // Sağ kolon kontrolü
            for keyword in rightColumnKeywords {
                if upperLine.contains(keyword) {
                    xPosition = 0.55  // Sağ kolon
                    break
                }
            }
            
            // Alt bölge kontrolü (Y pozisyonu düzeltmesi)
            for keyword in bottomKeywords {
                if upperLine.contains(keyword) {
                    // Alt bölgede olmasını sağla
                    currentY = max(currentY, 0.65)
                    if keyword == "GENEL TOPLAM" || keyword == "ÖDENECEK TUTAR" {
                        xPosition = 0.55  // Sağ-alt
                    }
                    break
                }
            }
            
            let block = TextBlock(
                text: line,
                frame: CGRect(x: xPosition, y: currentY, width: 0.35, height: lineHeight)
            )
            blocks.append(block)
            
            currentY += lineHeight + lineSpacing
            
            // Sayfa sınırını aşmayı önle
            if currentY > 0.95 {
                currentY = 0.95
            }
        }
        
        return blocks
    }
    
    /// PDF sayfasını UIImage'a çevirir
    private func renderPageToImage(_ page: PDFPage) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

// MARK: - Image Input Provider (Galeri & Kamera için ortak)

/// UIImage üzerinden Vision OCR ile metin çıkarır
struct ImageInputProvider: InputProviding {
    let image: UIImage
    
    func process() async throws -> [TextBlock] {
        guard let cgImage = image.cgImage else {
            throw InputError.emptyImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: InputError.processingFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: InputError.ocrFailed)
                    return
                }
                
                let blocks = observations.compactMap { observation -> TextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    
                    // Vision koordinatlarını standart UIKit koordinatlarına çevir
                    let visionRect = observation.boundingBox
                    let flippedRect = CGRect(
                        x: visionRect.origin.x,
                        y: 1 - visionRect.origin.y - visionRect.height,
                        width: visionRect.width,
                        height: visionRect.height
                    )
                    
                    return TextBlock(text: candidate.string, frame: flippedRect)
                }
                
                continuation.resume(returning: blocks)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["tr-TR", "en-US"]
            request.usesLanguageCorrection = true
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: InputError.ocrFailed)
            }
        }
    }
}

// MARK: - Gallery Input Provider (PhotosPicker entegrasyonu)

/// PhotosPicker üzerinden seçilen görselleri işler
/// - Kullanım: GalleryInputProvider ile PhotosPickerItem'ı UIImage'a dönüştürüp OCR uygular
struct GalleryInputProvider: InputProviding {
    let pickerItem: PhotosPickerItem
    
    func process() async throws -> [TextBlock] {
        // PhotosPickerItem'dan Data yükle
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw InputError.emptyImage
        }
        
        print("GalleryInputProvider: Görsel yüklendi, OCR başlatılıyor...")
        
        // ImageInputProvider'a delege et
        return try await ImageInputProvider(image: image).process()
    }
}

/// Birden fazla galeri görselini toplu işleyen provider
struct BatchGalleryInputProvider {
    let pickerItems: [PhotosPickerItem]
    
    /// Tüm görselleri paralel işleyerek TextBlock dizileri döndürür
    func processAll() async throws -> [[TextBlock]] {
        try await withThrowingTaskGroup(of: [TextBlock].self) { group in
            for item in pickerItems {
                group.addTask {
                    try await GalleryInputProvider(pickerItem: item).process()
                }
            }
            
            var results: [[TextBlock]] = []
            for try await blocks in group {
                results.append(blocks)
            }
            return results
        }
    }
}

// MARK: - Input Manager (Facade)

/// Tüm girdi kaynaklarını yöneten ana facade sınıfı
/// - Kullanım: `let blocks = try await InputManager.shared.process(source: .pdf(url))`
final class InputManager {
    
    static let shared = InputManager()
    
    init() {}
    
    /// Belirtilen kaynaktan metin bloklarını çıkarır
    /// - Parameter source: Girdi kaynağı (PDF, Image, Camera)
    /// - Returns: Normalize edilmiş TextBlock dizisi
    func process(source: InputSource) async throws -> [TextBlock] {
        switch source {
        case .pdf(let url):
            return try await PDFInputProvider(url: url).process()
        case .image(let image):
            return try await ImageInputProvider(image: image).process()
        case .camera:
            // Kamera için önce ScannerView üzerinden görsel alınmalı
            // Bu case dışarıdan UIImage ile çağrılacak
            throw InputError.processingFailed("Kamera için önce görsel taranmalı.")
        }
    }
    
    // MARK: - Callback-Based Convenience Methods
    
    /// UIImage'den blok çıkarır (callback-based)
    func extractBlocks(from image: UIImage, completion: @escaping ([TextBlock]) -> Void) {
        Task {
            do {
                let blocks = try await ImageInputProvider(image: image).process()
                completion(blocks)
            } catch {
                print("InputManager Error: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    /// PDF URL'den blok çıkarır (callback-based)
    func extractBlocks(from url: URL, completion: @escaping ([TextBlock]) -> Void) {
        Task {
            do {
                let blocks = try await PDFInputProvider(url: url).process()
                completion(blocks)
            } catch {
                print("InputManager Error: \(error.localizedDescription)")
                completion([])
            }
        }
    }
}


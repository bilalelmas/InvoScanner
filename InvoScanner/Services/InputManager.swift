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
struct PDFInputProvider: InputProviding {
    let url: URL
    
    func process() async throws -> [TextBlock] {
        guard let document = PDFDocument(url: url) else {
            throw InputError.invalidPDF
        }
        
        // Adım 1: PDFKit ile doğrudan metin denemesi
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        let cleanText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Yeterli metin varsa, TextBlock olarak dön (koordinatsız)
        if cleanText.count > 50 {
            print("PDFInputProvider: PDFKit ile \(cleanText.count) karakter alındı.")
            // Native PDF'ler için tek bir büyük TextBlock döndürüyoruz
            return [TextBlock(text: cleanText, frame: .zero)]
        }
        
        // Adım 2: Yetersizse Vision OCR
        print("PDFInputProvider: PDFKit yetersiz, Vision OCR devreye giriyor...")
        guard let page = document.page(at: 0) else {
            throw InputError.invalidPDF
        }
        
        let image = renderPageToImage(page)
        return try await ImageInputProvider(image: image).process()
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
    
    private init() {}
    
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
}

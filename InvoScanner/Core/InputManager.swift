import Foundation
import UIKit
import PDFKit
import Vision
import PhotosUI
import SwiftUI

// MARK: - Girdi Sağlayıcı Protokolü

/// Tüm girdi kaynaklarını (PDF, Görsel, Kamera) normalize eden protokol
protocol InputProviding {
    /// Girdiyi işleyerek metin bloklarına dönüştürür
    func process() async throws -> [TextBlock]
}

// MARK: - Girdi Kaynağı

/// Desteklenen girdi kaynakları
enum InputSource {
    case pdf(URL)
    case image(UIImage)
    case camera
}

// MARK: - Hata Tanımları

/// Girdi işleme hataları
enum InputError: LocalizedError {
    case invalidPDF
    case emptyImage
    case ocrFailed
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF: return "PDF dosyası geçersiz."
        case .emptyImage: return "Görsel boş veya işlenemedi."
        case .ocrFailed: return "OCR işlemi başarısız."
        case .processingFailed(let reason): return "Hata: \(reason)"
        }
    }
}

// MARK: - PDF Girdi Sağlayıcı

/// PDF dosyalarından metin ayıklar (PDFKit veya Vision OCR)
struct PDFInputProvider: InputProviding {
    let url: URL
    
    func process() async throws -> [TextBlock] {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let document = PDFDocument(url: url) else {
            throw InputError.invalidPDF
        }
        
        // PDF metin katmanını oku
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        let cleanText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Metin katmanı varsa bloklara çevir
        if cleanText.count > 50 {
            return convertTextToBlocks(cleanText)
        }
        
        // Metin katmanı yoksa görsel olarak render et ve OCR uygula
        guard let page = document.page(at: 0) else {
            throw InputError.invalidPDF
        }
        
        let image = renderPageToImage(page)
        return try await ImageInputProvider(image: image).process()
    }
    
    /// Ham metni yapay koordinatlı bloklara çevirir
    private func convertTextToBlocks(_ text: String) -> [TextBlock] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return [] }
        
        var blocks: [TextBlock] = []
        let lineHeight: CGFloat = 0.020
        let lineSpacing: CGFloat = 0.006
        
        let rightColumnKeywords = [
            "FATURA NO", "BELGE NO", "TARIH", "TARİH", "DÜZENLEME", "DUZENLEME",
            "TOPLAM", "KDV", "MATRAH", "ODENECEK", "ÖDENECEK", "SENARYO", 
            "FATURA TİPİ", "FATURA TIPI", "SAAT"
        ]
        
        let bottomKeywords = [
            "GENEL TOPLAM", "ÖDENECEK TUTAR", "YALNIZ", "IBAN", "BANKA",
            "HESAP NO", "ETTN"
        ]
        
        var currentY: CGFloat = 0.05
        
        for line in lines {
            let upperLine = line.uppercased()
            var xPosition: CGFloat = 0.1
            
            for keyword in rightColumnKeywords {
                if upperLine.contains(keyword) {
                    xPosition = 0.55
                    break
                }
            }
            
            for keyword in bottomKeywords {
                if upperLine.contains(keyword) {
                    currentY = max(currentY, 0.65)
                    if keyword == "GENEL TOPLAM" || keyword == "ÖDENECEK TUTAR" {
                        xPosition = 0.55
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
            if currentY > 0.95 { currentY = 0.95 }
        }
        
        return blocks
    }
    
    /// PDF sayfasını görsele dönüştürür
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

// MARK: - Görsel Girdi Sağlayıcı

/// Görselleri Vision OCR ile işler
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

// MARK: - Galeri Girdi Sağlayıcı

/// Galeriden seçilen öğeleri işler
struct GalleryInputProvider: InputProviding {
    let pickerItem: PhotosPickerItem
    
    func process() async throws -> [TextBlock] {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw InputError.emptyImage
        }
        
        return try await ImageInputProvider(image: image).process()
    }
}

// MARK: - Girdi Yöneticisi (Facade)

/// Tüm girdi kaynaklarını yöneten ana sınıf
final class InputManager {
    
    static let shared = InputManager()
    
    init() {}
    
    /// Kaynaktan metin bloklarını ayıklar
    func process(source: InputSource) async throws -> [TextBlock] {
        switch source {
        case .pdf(let url):
            return try await PDFInputProvider(url: url).process()
        case .image(let image):
            return try await ImageInputProvider(image: image).process()
        case .camera:
            throw InputError.processingFailed("Kamera taraması ScannerView üzerinden yapılmalıdır.")
        }
    }
    
    // MARK: - Yardımcı Metotlar (Callback)
    
    /// Görselden blok çıkarır
    func extractBlocks(from image: UIImage, completion: @escaping ([TextBlock]) -> Void) {
        Task {
            do {
                let blocks = try await ImageInputProvider(image: image).process()
                completion(blocks)
            } catch {
                completion([])
            }
        }
    }
    
    /// PDF'den blok çıkarır
    func extractBlocks(from url: URL, completion: @escaping ([TextBlock]) -> Void) {
        Task {
            do {
                let blocks = try await PDFInputProvider(url: url).process()
                completion(blocks)
            } catch {
                completion([])
            }
        }
    }
}

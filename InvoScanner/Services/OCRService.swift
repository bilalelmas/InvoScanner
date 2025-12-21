import Foundation
import Vision
import PDFKit
import UIKit

class OCRService {
    
    /// Vision Framework kullanarak UIImage üzerinden metin ayıklar
    func extractText(from image: UIImage, completion: @escaping ([TextBlock]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion([])
                return
            }
            
            let blocks = observations.compactMap { observation -> TextBlock? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                
                // Vision sol-alt köşe orijinli normalize koordinatlar (0..1) döndürür
                // Gerekirse standart Sol-Üst orijine dönüştürebiliriz
                // Not: Vision'ın y'si UIKit'e göre terstir. 0 alt, 1 üsttür.
                // Sezgisel olması için (0 üst, 1 alt), Y'yi ters çeviriyoruz.
                
                let visionRect = observation.boundingBox
                let flippedRect = CGRect(x: visionRect.origin.x,
                                         y: 1 - visionRect.origin.y - visionRect.height,
                                         width: visionRect.width,
                                         height: visionRect.height)
                
                return TextBlock(text: candidate.string, frame: flippedRect)
            }
            
            completion(blocks)
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["tr-TR", "en-US"]
        
        do {
            try handler.perform([request])
        } catch {
            print("OCR Hatası: \(error)")
            completion([])
        }
    }
    
    /// Hibrit Ayıklama: Önce PDFKit (Text), olmazsa Vision OCR (Image)
    func extractText(from pdfURL: URL, completion: @escaping (String, [TextBlock]?) -> Void) {
        guard let document = PDFDocument(url: pdfURL) else {
            completion("", nil)
            return
        }
        
        // Adım 1: PDFKit ile Doğrudan Metin Denemesi
        // Tüm sayfalardaki metni birleştir
        let pageCount = document.pageCount
        var fullText = ""
        for i in 0..<pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        // Temizlik ve Kontrol
        let cleanText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.count > 50 {
            print("OCRService: PDFKit üzerinden metin alındı (\(cleanText.count) karakter).")
            completion(cleanText, nil) // Koordinat yok, sadece metin
            return
        }
        
        // Adım 2: Yetersiz metin ise Görüntü İşleme (Vision OCR)
        print("OCRService: PDFKit yetersiz, Vision OCR devreye giriyor...")
        guard let page = document.page(at: 0) else {
            completion("", nil)
            return
        }
        
        // Görüntüye çevir
        let image = self.image(from: page)
        
        // Vision OCR çalıştır
        self.extractText(from: image) { blocks in
            // Bloklardan metni oluştur
            let ocrText = blocks.map { $0.text }.joined(separator: "\n")
            completion(ocrText, blocks)
        }
    }
    
    func generateImage(from pdfURL: URL) -> UIImage? {
        guard let document = PDFDocument(url: pdfURL),
              let page = document.page(at: 0) else { return nil }
        return image(from: page)
    }
    
    private func image(from page: PDFPage) -> UIImage {
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return image
    }
}

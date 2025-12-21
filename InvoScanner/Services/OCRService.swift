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
    
    /// PDF belgesinden metin ayıklar (MVP için sadece 1. Sayfa)
    func extractText(from pdfURL: URL) -> [TextBlock] {
        guard let document = PDFDocument(url: pdfURL),
              let page = document.page(at: 0) else {
            return []
        }
        
        // PDFKit ayıklaması farklıdır. Ham metin veya özellikli metin alabiliriz.
        // Standart API ile her satır için hassas sınırlayıcı kutular almak zor olabilir.
        // 'Lightweight' yapı için sadece string bilgisini alabiliriz.
        // ANCAK, stratejilerimiz uzamsal konumlara (Üst %20, Alt %30) dayanmaktadır.
        // PDF'den TextBlock oluşturmanın bir yoluna ihtiyacımız var.
        // Tek tip boru hattı için sağlam yol: PDF sayfasını Görüntüye dönüştür ve Vision çalıştır.
        // Bu, hem PDF hem de Kamera mantığı için aynı koordinat sistemini sağlar.
        
        _ = self.image(from: page)
        // Burada senkron/asenkron olmamız gerektiğinden, asenkron vision çağrısını uyarlamak gerekir.
        // Bu v0 sürümü için basitlik adına, ViewModel seviyesinde callback modelini kullandığımızı varsayalım
        // veya burada bekleyelim (UI için ideal değil). Temiz tutmak için Görüntü ayıklama mantığını yeniden kullanalım
        // ancak bu fonksiyon imzası senkron dönüş öneriyor. Tasarımı standart asenkron yapıya düzeltelim.
        return [] // Yer tutucu: ViewModel'ler "render et sonra ayıkla" akışını yönetmeli.
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

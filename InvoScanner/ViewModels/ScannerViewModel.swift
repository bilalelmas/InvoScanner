import Foundation
import SwiftUI
import Combine
import Vision

class ScannerViewModel: ObservableObject {
    @Published var scannedInvoice: Invoice?
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    private let ocrService = OCRService()
    private let parser = InvoiceParser()
    
    func scan(image: UIImage) {
        self.isScanning = true
        self.scannedInvoice = nil
        self.errorMessage = nil
        
        ocrService.extractText(from: image) { [weak self] blocks in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if blocks.isEmpty {
                    self.errorMessage = "Metin bulunamadı veya okunamadı."
                    self.isScanning = false
                    return
                }
                
                let invoice = self.parser.parse(blocks: blocks)
                self.scannedInvoice = invoice
                self.isScanning = false
            }
        }
    }
    
    func scan(pdfURL: URL) {
        // Tutarlı Vision OCR için ilk sayfayı görüntüye dönüştür
        if let image = ocrService.generateImage(from: pdfURL) {
            scan(image: image)
        } else {
            self.errorMessage = "PDF dosyası okunamadı."
        }
    }
}

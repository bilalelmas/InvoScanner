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
        self.isScanning = true
        self.errorMessage = nil
        
        ocrService.extractText(from: pdfURL) { [weak self] text, blocks in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if text.isEmpty {
                    self.errorMessage = "PDF içeriği okunamadı."
                    self.isScanning = false
                    return
                }
                
                // Parser artık hem metin hem de opsiyonel blokları alacak
                let invoice = self.parser.parse(text: text, blocks: blocks)
                self.scannedInvoice = invoice
                
                // Hata ayıklama için konsola bas
                print("ScannerVM: Fatura Ayrıştırıldı (Güven: \(String(format: "%.2f", invoice.confidenceScore)))")
                print("  - Tedarikçi: \(invoice.supplierName ?? "Yok")")
                print("  - Tutar: \(invoice.totalAmount != nil ? "\(invoice.totalAmount!)" : "Yok")")
                print("  - ETTN: \(invoice.ettn?.uuidString ?? "Yok")")
                print("  - Fatura No: \(invoice.invoiceNumber ?? "Yok")")
                
                self.isScanning = false
            }
        }
    }
}

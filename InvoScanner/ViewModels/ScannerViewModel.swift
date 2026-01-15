import Foundation
import SwiftUI
import Combine
import Vision

// MARK: - Scanner ViewModel (Entegrasyonu)

/// Fatura tarama ve ayrıştırma işlemlerini yöneten ViewModel
/// Spatial Engine ile entegre çalışır
class ScannerViewModel: ObservableObject {
    @Published var scannedInvoice: Invoice?
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    // Yeni bileşenler
    private let inputManager = InputManager()
    private let spatialParser = SpatialParser()
    
    // MARK: - UIImage'den Tarama
    
    func scan(image: UIImage) {
        self.isScanning = true
        self.scannedInvoice = nil
        self.errorMessage = nil
        
        // InputManager ile koordinatlı blok çıkarımı
        inputManager.extractBlocks(from: image) { [weak self] blocks in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if blocks.isEmpty {
                    self.errorMessage = "Metin bulunamadı veya okunamadı."
                    self.isScanning = false
                    return
                }
                
                // SpatialParser ile ayrıştırma
                let result = self.spatialParser.parse(blocks)
                let invoice = Invoice(from: result)
                
                self.scannedInvoice = invoice
                self.isScanning = false
                
                self.debugPrint(invoice)
            }
        }
    }
    
    // MARK: - PDF'den Tarama
    
    func scan(pdfURL: URL) {
        self.isScanning = true
        self.errorMessage = nil
        
        // InputManager ile PDF'den koordinatlı blok çıkarımı
        inputManager.extractBlocks(from: pdfURL) { [weak self] blocks in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if blocks.isEmpty {
                    self.errorMessage = "PDF içeriği okunamadı."
                    self.isScanning = false
                    return
                }
                
                // SpatialParser ile ayrıştırma
                let result = self.spatialParser.parse(blocks)
                let invoice = Invoice(from: result)
                
                self.scannedInvoice = invoice
                self.isScanning = false
                
                self.debugPrint(invoice)
            }
        }
    }
    
    // MARK: - Debug
    
    private func debugPrint(_ invoice: Invoice) {
        print("═══════════════════════════════════════")
        print("ScannerVM  Fatura Ayrıştırıldı")
        print("  Güven Skoru: \(String(format: "%.2f", invoice.confidenceScore))")
        print("  Otomatik Kabul: \(invoice.isAutoAccepted ? "✓" : "✗")")
        print("───────────────────────────────────────")
        print("  ETTN: \(invoice.ettn?.uuidString ?? "—")")
        print("  Fatura No: \(invoice.invoiceNumber ?? "—")")
        print("  Tedarikçi: \(invoice.supplierName ?? "—")")
        print("  Tutar: \(invoice.totalAmount.map { "\($0) TL" } ?? "—")")
        print("═══════════════════════════════════════")
    }
}

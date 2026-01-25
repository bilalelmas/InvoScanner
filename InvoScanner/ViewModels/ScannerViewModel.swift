import Foundation
import UIKit
import SwiftUI
import Combine

// MARK: - Scanner ViewModel

/// Tarama ve ayrıştırma işlemlerini yönetir
class ScannerViewModel: ObservableObject {
    @Published var scannedInvoice: Invoice?
    @Published var isScanning = false
    @Published var errorMessage: String?
    
    // MARK: - Bağımlılıklar
    
    private let inputManager = InputManager()
    private let spatialParser = SpatialParser()
    
    // MARK: - Görsel Tarama
    
    /// UIImage üzerinden fatura tarar
    func scan(image: UIImage) {
        self.isScanning = true
        self.scannedInvoice = nil
        self.errorMessage = nil
        
        /// Koordinat bazlı metin ayıklama
        inputManager.extractBlocks(from: image) { [weak self] blocks in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if blocks.isEmpty {
                    self.errorMessage = "Metin tespit edilemedi."
                    self.isScanning = false
                    return
                }
                
                /// Uzamsal ayrıştırma (Spatial Parsing)
                let result = self.spatialParser.parse(blocks)
                let invoice = Invoice(from: result)
                
                self.scannedInvoice = invoice
                self.isScanning = false
                
                self.debugPrint(invoice)
            }
        }
    }
    
    // MARK: - PDF Tarama
    
    /// PDF dosyası üzerinden fatura tarar
    func scan(pdfURL: URL) {
        self.isScanning = true
        self.errorMessage = nil
        
        /// PDF'den metin bloklarını ayıkla
        inputManager.extractBlocks(from: pdfURL) { [weak self] blocks in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if blocks.isEmpty {
                    self.errorMessage = "PDF içeriği okunamadı."
                    self.isScanning = false
                    return
                }
                
                /// Uzamsal ayrıştırma
                let result = self.spatialParser.parse(blocks)
                let invoice = Invoice(from: result)
                
                self.scannedInvoice = invoice
                self.isScanning = false
                
                self.debugPrint(invoice)
            }
        }
    }
    
    // MARK: - Hata Ayıklama
    
    /// Ayrıştırma sonuçlarını konsola yazdırır
    private func debugPrint(_ invoice: Invoice) {
        print("═══════════════════════════════════════")
        print("ScannerVM: Fatura Ayrıştırıldı")
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

import SwiftUI
import UniformTypeIdentifiers
import VisionKit

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showDocumentPicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack {
                if let invoice = viewModel.scannedInvoice {
                    ResultView(invoice: invoice)
                } else if viewModel.isScanning {
                    ProgressView("Taranıyor...")
                } else {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding()
                    } else {
                        ContentUnavailableView("Belge Seçin", systemImage: "doc.viewfinder", description: Text("Analiz etmek için bir fatura fotoğrafı veya PDF'i yükleyin"))
                    }
                }
                
                Spacer()
                
                Button(action: { showDocumentPicker = true }) {
                    Label("Belge Yükle", systemImage: "arrow.up.doc")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("InvoScanner V0")
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(selectedImage: $selectedImage, onPDFSelected: { url in
                    viewModel.scan(pdfURL: url)
                }, onImageSelected: { image in
                    viewModel.scan(image: image)
                })
            }
        }
    }
}

// Sonuçlar için alt görünüm
struct ResultView: View {
    let invoice: Invoice
    
    var body: some View {
        List {
            Section("Analiz Sonuçları") {
                LabeledContent("Satıcı", value: invoice.supplierName ?? "Bulunamadı")
                LabeledContent("Tarih", value: invoice.date?.formatted(date: .numeric, time: .omitted) ?? "Bulunamadı")
                LabeledContent("Toplam", value: invoice.totalAmount?.formatted(.currency(code: "TRY")) ?? "Bulunamadı")
                LabeledContent("ETTN", value: invoice.ettn?.uuidString ?? "Bulunamadı")
                if let invoiceNo = invoice.invoiceNumber {
                    LabeledContent("Fatura No", value: invoiceNo)
                }
            }
            
            Section("OCR Kalitesi") {
                HStack {
                    Text("Güven Skoru")
                    Spacer()
                    Text(String(format: "%.0f%%", invoice.confidenceScore * 100))
                        .foregroundStyle(invoice.isAutoAccepted ? .green : .orange)
                    Image(systemName: invoice.isAutoAccepted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(invoice.isAutoAccepted ? .green : .orange)
                }
            }
        }
    }
}

// Basit Belge Seçici Sarmalayıcı
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onPDFSelected: (URL) -> Void
    var onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Security-scoped erişimi başlat
            // NOT: PDF için erişimi InputManager yönetiyor (async işlem nedeniyle)
            // Image için burada durdurabiliriz çünkü senkron işlem
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            if url.pathExtension.lowercased() == "pdf" {
                // PDF: Erişimi InputManager'a bırak (async işlem)
                // InputManager.extractBlocks içinde startAccess tekrar çağrılacak
                // ve işlem bitince stopAccess yapılacak
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
                parent.onPDFSelected(url)
            } else {
                // Image: Senkron işle ve erişimi kapat
                defer {
                    if didStartAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    parent.selectedImage = image
                    parent.onImageSelected(image)
                }
            }
        }
    }
}

// MARK: - Document Camera View (VNDocumentCameraViewController Wrapper)

/// VNDocumentCameraViewController için SwiftUI sarmalayıcısı
/// - Kullanım: Anlık belge tarama için kamera arayüzü sağlar
struct DocumentCameraView: UIViewControllerRepresentable {
    
    /// Tarama tamamlandığında çağrılır
    var onScanComplete: ([UIImage]) -> Void
    
    /// Tarama iptal edildiğinde veya hata oluştuğunda çağrılır
    var onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScanComplete: onScanComplete, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanComplete: ([UIImage]) -> Void
        let onCancel: () -> Void
        
        init(onScanComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScanComplete = onScanComplete
            self.onCancel = onCancel
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: pageIndex))
            }
            controller.dismiss(animated: true) { [weak self] in
                self?.onScanComplete(images)
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [weak self] in
                self?.onCancel()
            }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("DocumentCamera Hatası: \(error.localizedDescription)")
            controller.dismiss(animated: true) { [weak self] in
                self?.onCancel()
            }
        }
    }
    
    /// Cihazda doküman tarama desteği olup olmadığını kontrol eder
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }
}

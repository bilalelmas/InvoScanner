import SwiftUI
import UniformTypeIdentifiers
import VisionKit

// MARK: - Scanner View (Neo-Glass)

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    
    // UI States
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    
    // Navigation
    @State private var showDetail = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Atmosfer
                CrystalBackground()
                
                // 2. İçerik
                VStack(spacing: 40) {
                    
                    // Başlık
                    VStack(spacing: 8) {
                        Text("Belge Tara")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .cyan.opacity(0.5), radius: 10)
                        
                        Text("Yapay zeka ile faturalarınızı dijitalleştirin")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Ana Aksiyonlar
                    if viewModel.isScanning {
                        glassLoadingView
                    } else {
                        HStack(spacing: 24) {
                            // Kamera Butonu
                            actionButton(
                                icon: "camera.fill",
                                title: "Kamera",
                                color: .cyan
                            ) {
                                if DocumentCameraView.isSupported {
                                    showCamera = true
                                }
                            }
                            
                            // Galeri Butonu
                            actionButton(
                                icon: "photo.fill",
                                title: "Galeri / PDF",
                                color: .purple
                            ) {
                                showDocumentPicker = true
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Alt Bilgi
                    Text("Desteklenenler: Fiş, Fatura, PDF")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 20)
                }
                .padding()
            }
            // Kamera Sheet
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView(onScanComplete: { images in
                    if let first = images.first {
                        self.selectedImage = first
                        viewModel.scan(image: first)
                    }
                }, onCancel: {
                    // İptal
                })
                .ignoresSafeArea()
            }
            // Dosya Seçici Sheet
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(selectedImage: $selectedImage, onPDFSelected: { url in
                    viewModel.scan(pdfURL: url)
                }, onImageSelected: { image in
                    viewModel.scan(image: image)
                })
            }
            // Sonuç Detay Sheet (Düzenleme ve Kaydetme)
            .sheet(isPresented: $showDetail, onDismiss: {
                // Sheet kapandığında (Kaydet veya İptal sonrası) state'i temizle
                viewModel.scannedInvoice = nil
            }) {
                if let invoice = viewModel.scannedInvoice {
                    InvoiceDetailView(invoice: invoice, scannedImage: selectedImage, onSave: {
                        // Kayıt başarılı olduğunda:
                        // Eğer Dashboard'dan modal olarak açıldıysa bu view'i kapat.
                        dismiss()
                    })
                }
            }
            // ViewModel Dinleme
            .onChange(of: viewModel.scannedInvoice) { oldValue, newValue in
                if newValue != nil {
                    showDetail = true
                }
            }
            .onChange(of: viewModel.errorMessage) { oldValue, newValue in
                // Hata gösterimi eklenebilir (Alert)
            }
        }
    }
    
    // MARK: - Components
    
    private var glassLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            
            Text("Analiz Ediliyor...")
                .font(.headline)
                .foregroundStyle(.white)
                .shadow(color: .blue, radius: 10)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
    
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .shadow(color: color, radius: 10)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(width: 140, height: 140)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Helpers

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
            
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            if url.pathExtension.lowercased() == "pdf" {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
                parent.onPDFSelected(url)
            } else {
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

struct DocumentCameraView: UIViewControllerRepresentable {
    
    var onScanComplete: ([UIImage]) -> Void
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
    
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }
}

#Preview {
    ScannerView()
}

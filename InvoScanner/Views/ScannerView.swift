import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

// MARK: - Tarayıcı Ekranı

/// Fiş ve faturaları taramak için kullanılan ana arayüz
struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    
    // UI Durumları
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // Navigasyon
    @State private var showDetail = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Kristal arka plan
                CrystalBackground()
                
                // İçerik katmanı
                VStack(spacing: 40) {
                    
                    // Başlık bölümü
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
                    
                    // Ana aksiyon butonları
                    if viewModel.isScanning {
                        glassLoadingView
                    } else {
                        HStack(spacing: 16) {
                            // Kamera butonu
                            actionButton(
                                icon: "camera.fill",
                                title: "Kamera",
                                color: .cyan
                            ) {
                                if DocumentCameraView.isSupported {
                                    showCamera = true
                                }
                            }
                            
                            // Galeri seçici (PhotosPicker)
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.white)
                                        .shadow(color: .purple, radius: 8)
                                    
                                    Text("Galeri")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 100, height: 100)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            // Dosya/PDF butonu
                            actionButton(
                                icon: "doc.fill",
                                title: "Dosya",
                                color: .orange
                            ) {
                                showDocumentPicker = true
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Alt bilgilendirme
                    Text("Desteklenenler: Fiş, Fatura, PDF")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 20)
                }
                .padding()
            }
            // Kamera ekranı
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView(onScanComplete: { images in
                    if let first = images.first {
                        self.selectedImage = first
                        viewModel.scan(image: first)
                    }
                }, onCancel: { })
                .ignoresSafeArea()
            }
            // Dosya seçici
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(selectedImage: $selectedImage, onPDFSelected: { url in
                    viewModel.scan(pdfURL: url)
                }, onImageSelected: { image in
                    viewModel.scan(image: image)
                })
            }
            // Sonuç detay ekranı
            .sheet(isPresented: $showDetail, onDismiss: {
                viewModel.scannedInvoice = nil
            }) {
                if let invoice = viewModel.scannedInvoice {
                    InvoiceDetailView(invoice: invoice, scannedImage: selectedImage, onSave: {
                        dismiss()
                    })
                }
            }
            // ViewModel dinleyicileri
            .onChange(of: viewModel.scannedInvoice) { _, newValue in
                if newValue != nil { showDetail = true }
            }
            // Galeri seçimi takibi
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let item = newValue,
                       let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            self.selectedImage = image
                            viewModel.scan(image: image)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Alt Bileşenler
    
    /// Analiz sırasında gösterilen yükleme ekranı
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
    
    /// Ortak buton tasarımı
    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(color: color, radius: 8)
                
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 100, height: 100)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Yardımcı Yapılar

/// Dosya ve PDF seçici sarmalayıcısı
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
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(parent: DocumentPicker) { self.parent = parent }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            
            if url.pathExtension.lowercased() == "pdf" {
                if access { url.stopAccessingSecurityScopedResource() }
                parent.onPDFSelected(url)
            } else {
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    parent.selectedImage = image
                    parent.onImageSelected(image)
                }
            }
        }
    }
}

/// Doküman kamerası sarmalayıcısı (VNDocumentCamera)
struct DocumentCameraView: UIViewControllerRepresentable {
    var onScanComplete: ([UIImage]) -> Void
    var onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(onScanComplete: onScanComplete, onCancel: onCancel) }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanComplete: ([UIImage]) -> Void
        let onCancel: () -> Void
        
        init(onScanComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScanComplete = onScanComplete
            self.onCancel = onCancel
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            controller.dismiss(animated: true) { [weak self] in self?.onScanComplete(images) }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [weak self] in self?.onCancel() }
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) { [weak self] in self?.onCancel() }
        }
    }
    
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }
}

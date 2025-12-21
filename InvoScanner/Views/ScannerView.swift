import SwiftUI
import UniformTypeIdentifiers

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
            }
            
            Section("Ham Veri Blokları") {
                ForEach(invoice.rawBlocks) { block in
                    Text(block.text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
            
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                if url.pathExtension.lowercased() == "pdf" {
                    parent.onPDFSelected(url)
                } else {
                    if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        parent.selectedImage = image
                        parent.onImageSelected(image)
                    }
                }
            }
        }
    }
}

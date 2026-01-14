import SwiftUI
import SwiftData

// MARK: - Invoice Detail View

/// Fatura detay ve düzenleme görünümü
/// - Split View: Görsel + Form
/// - Hibrit Depolama: Görsel disk'e, metadata SwiftData'ya kaydedilir
struct InvoiceDetailView: View {
    
    let invoice: Invoice
    let scannedImage: UIImage?
    
    // MARK: - SwiftData
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    /// Düzenleme için mutable kopya
    @State private var editableInvoice: Invoice
    
    /// Orijinal OCR verisi (immutable snapshot for rollback)
    private let originalSnapshot: Invoice
    
    /// Düzenleme modu
    @State private var isEditing = false
    
    /// Alert gösterimi
    @State private var showDiscardAlert = false
    
    /// Kaydetme durumu
    @State private var showSaveSuccess = false
    @State private var isSaving = false
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Init
    
    init(invoice: Invoice, scannedImage: UIImage? = nil) {
        self.invoice = invoice
        self.scannedImage = scannedImage
        self._editableInvoice = State(initialValue: invoice)
        self.originalSnapshot = invoice
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > 600 {
                    // iPad: Yan yana Split View
                    HStack(spacing: 0) {
                        imagePreview
                            .frame(width: geometry.size.width * 0.4)
                        
                        Divider()
                        
                        formContent
                            .frame(width: geometry.size.width * 0.6)
                    }
                } else {
                    // iPhone: Dikey akış
                    ScrollView {
                        VStack(spacing: 20) {
                            imagePreview
                                .frame(height: 250)
                            
                            formContent
                            
                            // Kaydet Butonu (Floating)
                            saveButton
                                .padding(.top, 20)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Fatura Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("İptal") {
                            if hasChanges {
                                showDiscardAlert = true
                            } else {
                                cancelEditing()
                            }
                        }
                    } else {
                        Button("Kapat") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Tamam") {
                            isEditing = false
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Düzenle") {
                            isEditing = true
                        }
                    }
                }
            }
            .alert("Değişiklikleri Sil?", isPresented: $showDiscardAlert) {
                Button("Değişiklikleri Sil", role: .destructive) {
                    rollbackToSnapshot()
                }
                Button("Düzenlemeye Devam", role: .cancel) {}
            } message: {
                Text("Yaptığınız değişiklikler kaybolacak.")
            }
            .alert("Başarılı!", isPresented: $showSaveSuccess) {
                Button("Tamam") {
                    dismiss()
                }
            } message: {
                Text("Fatura başarıyla kaydedildi.")
            }
        }
    }
    
    // MARK: - Image Preview
    
    private var imagePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
            
            if let image = scannedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Fatura Önizlemesi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button {
            saveToDatabase()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
                Text(isSaving ? "Kaydediliyor..." : "Faturayı Kaydet")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSaving ? Color.gray : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isSaving)
    }
    
    // MARK: - Form Content
    
    private var formContent: some View {
        Form {
            // Satıcı Bilgisi
            Section("Satıcı Bilgisi") {
                if isEditing {
                    TextField("Satıcı Adı", text: Binding(
                        get: { editableInvoice.supplierName ?? "" },
                        set: { editableInvoice.supplierName = $0.isEmpty ? nil : $0 }
                    ))
                } else {
                    LabeledContent("Satıcı", value: editableInvoice.supplierName ?? "Bilinmiyor")
                }
            }
            
            // Tarih
            Section("Tarih") {
                if isEditing {
                    DatePicker("Fatura Tarihi", 
                               selection: Binding(
                                   get: { editableInvoice.date ?? Date() },
                                   set: { editableInvoice.date = $0 }
                               ), 
                               displayedComponents: .date)
                } else {
                    LabeledContent("Tarih", value: editableInvoice.date?.formatted(date: .long, time: .omitted) ?? "Bilinmiyor")
                }
            }
            
            // Tutar
            Section("Finansal Bilgiler") {
                if isEditing {
                    HStack {
                        Text("Toplam Tutar")
                        Spacer()
                        TextField("Tutar", value: Binding(
                            get: { editableInvoice.totalAmount ?? 0 },
                            set: { editableInvoice.totalAmount = $0 }
                        ), format: .currency(code: "TRY"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    }
                } else {
                    LabeledContent("Toplam", value: editableInvoice.totalAmount?.formatted(.currency(code: "TRY")) ?? "Bilinmiyor")
                }
            }
            
            // ETTN
            Section("Yasal Bilgiler") {
                if let ettn = editableInvoice.ettn {
                    LabeledContent("ETTN", value: ettn.uuidString)
                        .font(.caption)
                } else {
                    LabeledContent("ETTN", value: "Bulunamadı")
                }
                
                if let invoiceNo = editableInvoice.invoiceNumber {
                    LabeledContent("Fatura No", value: invoiceNo)
                }
            }
            
            // Güven Skoru
            Section("OCR Kalitesi") {
                HStack {
                    Text("Güven Skoru")
                    Spacer()
                    Text(String(format: "%.0f%%", editableInvoice.confidenceScore * 100))
                        .foregroundStyle(editableInvoice.isAutoAccepted ? .green : .orange)
                    
                    Image(systemName: editableInvoice.isAutoAccepted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(editableInvoice.isAutoAccepted ? .green : .orange)
                }
            }
        }
    }
    
    // MARK: - Computed
    
    /// Değişiklik yapıldı mı?
    private var hasChanges: Bool {
        editableInvoice.supplierName != originalSnapshot.supplierName ||
        editableInvoice.date != originalSnapshot.date ||
        editableInvoice.totalAmount != originalSnapshot.totalAmount
    }
    
    // MARK: - Actions
    
    private func cancelEditing() {
        isEditing = false
    }
    
    /// Orijinal snapshot'a geri dön (Rollback)
    private func rollbackToSnapshot() {
        editableInvoice = originalSnapshot
        isEditing = false
    }
    
    /// Faturayı SwiftData'ya kaydet (Hibrit Depolama)
    private func saveToDatabase() {
        isSaving = true
        
        Task {
            // 1. Görseli disk'e kaydet (Hibrit Depolama)
            var imageFileName: String? = nil
            if let image = scannedImage {
                imageFileName = ImageStorageService.shared.save(image: image, id: UUID())
            }
            
            // 2. SavedInvoice oluştur ve kaydet
            let savedInvoice = SavedInvoice(from: editableInvoice, imageFileName: imageFileName)
            
            await MainActor.run {
                modelContext.insert(savedInvoice)
                
                isSaving = false
                showSaveSuccess = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    var previewInvoice = Invoice()
    previewInvoice.ettn = UUID()
    previewInvoice.date = Date()
    previewInvoice.totalAmount = 1250.50
    previewInvoice.supplierName = "TRENDYOL HIZLI TESLİMAT"
    
    return InvoiceDetailView(invoice: previewInvoice)
        .modelContainer(for: SavedInvoice.self, inMemory: true)
}

import SwiftUI

// MARK: - Invoice Detail View

/// Fatura detay ve düzenleme görünümü
/// - Split View: Görsel + Form
/// - Immutable Snapshot: Rollback desteği için orijinal veri
struct InvoiceDetailView: View {
    
    let invoice: Invoice
    
    // MARK: - State
    
    /// Düzenleme için mutable kopya
    @State private var editableInvoice: Invoice
    
    /// Orijinal OCR verisi (immutable snapshot for rollback)
    private let originalSnapshot: Invoice
    
    /// Düzenleme modu
    @State private var isEditing = false
    
    /// Alert gösterimi
    @State private var showDiscardAlert = false
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Init
    
    init(invoice: Invoice) {
        self.invoice = invoice
        self._editableInvoice = State(initialValue: invoice)
        self.originalSnapshot = invoice // Immutable snapshot
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
                        Button("Kaydet") {
                            saveChanges()
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
        }
    }
    
    // MARK: - Image Preview
    
    private var imagePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
            
            // TODO: Gerçek PDF/Görsel önizlemesi eklenecek
            VStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("Fatura Önizlemesi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    LabeledContent("Satıcı", value: invoice.supplierName ?? "Bilinmiyor")
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
                    LabeledContent("Tarih", value: invoice.date?.formatted(date: .long, time: .omitted) ?? "Bilinmiyor")
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
                    LabeledContent("Toplam", value: invoice.totalAmount?.formatted(.currency(code: "TRY")) ?? "Bilinmiyor")
                }
            }
            
            // ETTN
            Section("Yasal Bilgiler") {
                if let ettn = invoice.ettn {
                    LabeledContent("ETTN", value: ettn.uuidString)
                        .font(.caption)
                } else {
                    LabeledContent("ETTN", value: "Bulunamadı")
                }
                
                if let invoiceNo = invoice.invoiceNumber {
                    LabeledContent("Fatura No", value: invoiceNo)
                }
            }
            
            // Güven Skoru
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
    
    private func saveChanges() {
        // TODO: SwiftData'ya kaydet
        isEditing = false
    }
}

// MARK: - Preview

#Preview {
    InvoiceDetailView(invoice: Invoice(
        ettn: UUID(),
        date: Date(),
        totalAmount: 1250.50,
        supplierName: "TRENDYOL HIZLI TESLİMAT"
    ))
}

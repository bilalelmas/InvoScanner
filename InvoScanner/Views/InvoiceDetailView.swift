import SwiftUI
import SwiftData

// MARK: - Invoice Detail View (Scanner Flow)

/// Fatura düzenleme ve kaydetme ekranı - Crystal UI
/// - Görsel odaklı tasarım
/// - Floating Save Button
struct InvoiceDetailView: View {
    
    let invoice: Invoice
    let scannedImage: UIImage?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var editableInvoice: Invoice
    private let originalSnapshot: Invoice
    
    @State private var isEditing = false
    @State private var showDiscardAlert = false
    @State private var showSaveSuccess = false
    @State private var isSaving = false
    
    /// Kaydetme başarılı olduğunda tetiklenir (Flow kontrolü için)
    var onSave: (() -> Void)? = nil
    
    init(invoice: Invoice, scannedImage: UIImage? = nil, onSave: (() -> Void)? = nil) {
        self.invoice = invoice
        self.scannedImage = scannedImage
        self._editableInvoice = State(initialValue: invoice)
        self.originalSnapshot = invoice
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            // Arka Plan
            CrystalBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Görsel Header
                    if let image = scannedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                            .frame(maxHeight: 300)
                    }
                    
                    // Form Kartı
                    VStack(spacing: 0) {
                        glassHeader("Fatura Bilgileri")
                        
                        VStack(spacing: 16) {
                            if isEditing {
                                GlassTextField(title: "Satıcı", text: Binding(
                                    get: { editableInvoice.supplierName ?? "" },
                                    set: { editableInvoice.supplierName = $0.isEmpty ? nil : $0 }
                                ), icon: "building.2.fill")
                                
                                GlassDatePicker(title: "Tarih", date: Binding(
                                    get: { editableInvoice.date ?? Date() },
                                    set: { editableInvoice.date = $0 }
                                ), icon: "calendar")
                                
                                GlassAmountField(title: "Tutar", amount: Binding(
                                    get: { editableInvoice.totalAmount ?? 0 },
                                    set: { editableInvoice.totalAmount = $0 }
                                ), icon: "turkishlirasign.circle.fill")
                                
                                GlassTextField(title: "Fatura No", text: Binding(
                                    get: { editableInvoice.invoiceNumber ?? "" },
                                    set: { editableInvoice.invoiceNumber = $0.isEmpty ? nil : $0 }
                                ), icon: "number")
                                
                                GlassTextField(title: "ETTN", text: Binding(
                                    get: { editableInvoice.ettn?.uuidString ?? "" },
                                    set: {
                                        if let uuid = UUID(uuidString: $0) {
                                            editableInvoice.ettn = uuid
                                        }
                                    }
                                ), icon: "barcode")
                                
                            } else {
                                GlassInfoRow(
                                    title: "Satıcı",
                                    value: editableInvoice.supplierName?.capitalized(with: Locale(identifier: "tr_TR")) ?? "Bilinmiyor",
                                    icon: "building.2.fill"
                                )
                                GlassInfoRow(
                                    title: "Tarih",
                                    value: editableInvoice.date?.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))) ?? "Bilinmiyor",
                                    icon: "calendar"
                                )
                                GlassInfoRow(
                                    title: "Tutar",
                                    value: editableInvoice.totalAmount?.formatted(.currency(code: "TRY")) ?? "Bilinmiyor",
                                    icon: "turkishlirasign.circle.fill"
                                )
                                
                                if let no = editableInvoice.invoiceNumber {
                                    GlassInfoRow(title: "No", value: no, icon: "number")
                                }
                                
                                if let ettn = editableInvoice.ettn {
                                    GlassInfoRow(title: "ETTN", value: ettn.uuidString, icon: "barcode")
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                }
                            }
                        }
                        .padding(20)
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
                    
                    // Güven Skoru
                    HStack {
                        Image(systemName: editableInvoice.isAutoAccepted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(editableInvoice.isAutoAccepted ? .green : .orange)
                        Text("Güven Skoru: %\(Int(editableInvoice.confidenceScore * 100))")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    // Boşluk
                    Color.clear.frame(height: 80)
                }
                .padding()
            }
            
            // Floating Action Buttons
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    if isEditing {
                        Button("İptal") {
                            rollbackToSnapshot()
                        }
                        .buttonStyle(GlassButtonStyle(color: .red))
                        
                        Button("Tamam") {
                            isEditing = false
                        }
                        .buttonStyle(GlassButtonStyle(color: .green))
                    } else {
                        Button {
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        
                        Button {
                            saveToDatabase()
                        } label: {
                            HStack {
                                Text(isSaving ? "Kaydediliyor..." : "Kaydet")
                                Image(systemName: "arrow.down.doc.fill")
                            }
                        }
                        .buttonStyle(GlassButtonStyle(color: .blue))
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("Başarılı!", isPresented: $showSaveSuccess) {
            Button("Tamam") {
                onSave?() // Parent'a haber ver
                dismiss() // Sayfayı kapat
            }
        } message: {
            Text("Fatura başarıyla kaydedildi.")
        }
    }
    
    // Logic
    private func rollbackToSnapshot() {
        editableInvoice = originalSnapshot
        isEditing = false
    }
    
    private func saveToDatabase() {
        isSaving = true
        
        // Metin Formatı: Title Case (TR Locale)
        if let currentName = editableInvoice.supplierName {
            editableInvoice.supplierName = currentName.capitalized(with: Locale(identifier: "tr_TR"))
        }
        
        Task {
            var imageFileName: String? = nil
            if let image = scannedImage {
                imageFileName = ImageStorageService.shared.save(image: image, id: UUID())
            }
            let savedInvoice = SavedInvoice(from: editableInvoice, imageFileName: imageFileName)
            await MainActor.run {
                modelContext.insert(savedInvoice)
                isSaving = false
                
                // Başarı geri bildirimi
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                showSaveSuccess = true
            }
        }
    }
    
    private func glassHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .padding()
        .background(.white.opacity(0.05))
    }
}

// MARK: - Saved Invoice Detail View (List Flow)

struct SavedInvoiceDetailView: View {
    let savedInvoice: SavedInvoice
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var invoiceImage: UIImage?
    @State private var isLoadingImage = true
    
    // Edit Mode States
    @State private var isEditing = false
    @State private var editableDraft: Invoice = Invoice()
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            CrystalBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Image
                    if let image = invoiceImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(radius: 10)
                    } else if isLoadingImage {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 200)
                            .overlay(ProgressView().tint(.white))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 150)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo.badge.exclamationmark")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("Görsel Yok")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                    
                    // Info Card
                    VStack(alignment: .leading, spacing: 16) {
                        if isEditing {
                            GlassTextField(title: "Satıcı", text: Binding(get: { editableDraft.supplierName ?? "" }, set: { editableDraft.supplierName = $0.isEmpty ? nil : $0 }), icon: "building.2.fill")
                            GlassDatePicker(title: "Tarih", date: Binding(get: { editableDraft.date ?? Date() }, set: { editableDraft.date = $0 }), icon: "calendar")
                            GlassAmountField(title: "Tutar", amount: Binding(get: { editableDraft.totalAmount ?? 0 }, set: { editableDraft.totalAmount = $0 }), icon: "turkishlirasign.circle.fill")
                            GlassTextField(title: "Fatura No", text: Binding(get: { editableDraft.invoiceNumber ?? "" }, set: { editableDraft.invoiceNumber = $0.isEmpty ? nil : $0 }), icon: "number")
                            GlassTextField(title: "ETTN", text: Binding(get: { editableDraft.ettn?.uuidString ?? "" }, set: { if let uuid = UUID(uuidString: $0) { editableDraft.ettn = uuid } }), icon: "barcode")
                        } else {
                            Text(savedInvoice.supplierName?.capitalized(with: Locale(identifier: "tr_TR")) ?? "Bilinmiyor").font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(.white)
                            Divider().background(.white.opacity(0.2))
                            GlassInfoRow(title: "Tarih", value: savedInvoice.date?.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))) ?? "-", icon: "calendar")
                            GlassInfoRow(title: "Tutar", value: savedInvoice.totalAmount?.formatted(.currency(code: "TRY")) ?? "-", icon: "banknote")
                            if let no = savedInvoice.invoiceNumber { GlassInfoRow(title: "No", value: no, icon: "number") }
                            if let ettn = savedInvoice.ettn { GlassInfoRow(title: "ETTN", value: ettn, icon: "barcode") }
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.15)))
                }
                .padding()
                .padding(.bottom, 80)
            }
            
            // Toolbar
            VStack {
                if !isEditing {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.6)) }
                        .padding()
                    }
                }
                Spacer()
                HStack(spacing: 16) {
                    if isEditing {
                        Button("İptal") { isEditing = false }.buttonStyle(GlassButtonStyle(color: .red))
                        Button("Kaydet") { saveChanges() }.buttonStyle(GlassButtonStyle(color: .green))
                    } else {
                        Button { showDeleteAlert = true } label: { Image(systemName: "trash") }.buttonStyle(GlassCircleButtonStyle()).foregroundStyle(.red)
                        Button { startEditing() } label: { HStack { Text("Düzenle"); Image(systemName: "pencil") } }.buttonStyle(GlassButtonStyle(color: .blue))
                    }
                }
                .padding(.horizontal).padding(.bottom, 20)
            }
        }
        .alert("Faturayı Sil", isPresented: $showDeleteAlert) {
            Button("Sil", role: .destructive) { deleteInvoice() }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Bu faturayı kalıcı olarak silmek istediğinizden emin misiniz?")
        }
        .task {
            if let fileName = savedInvoice.imageFileName {
                let image = await Task.detached(priority: .background) { ImageStorageService.shared.load(fileName: fileName) }.value
                await MainActor.run { self.invoiceImage = image; self.isLoadingImage = false }
            } else {
                await MainActor.run { self.isLoadingImage = false }
            }
        }
    }
    
    private func startEditing() {
        self.editableDraft = savedInvoice.toInvoice()
        self.isEditing = true
    }
    
    private func saveChanges() {
        savedInvoice.supplierName = editableDraft.supplierName?.capitalized(with: Locale(identifier: "tr_TR"))
        savedInvoice.date = editableDraft.date
        savedInvoice.totalAmount = editableDraft.totalAmount
        savedInvoice.invoiceNumber = editableDraft.invoiceNumber
        if let ettnUUID = editableDraft.ettn { savedInvoice.ettn = ettnUUID.uuidString } else { savedInvoice.ettn = nil }
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteInvoice() {
        if let fileName = savedInvoice.imageFileName { Task { ImageStorageService.shared.delete(fileName: fileName) } }
        modelContext.delete(savedInvoice)
        dismiss()
    }
}

// MARK: - Glass Components Helpers

struct GlassInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.cyan)
            
            Text(title)
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
    }
}

struct GlassTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
            TextField(title, text: $text)
                .foregroundStyle(.white)
        }
        .padding()
        .background(.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
    }
}

struct GlassAmountField: View {
    let title: String
    @Binding var amount: Decimal
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
            TextField(title, value: $amount, format: .currency(code: "TRY"))
                .keyboardType(.decimalPad)
                .foregroundStyle(.white)
        }
        .padding()
        .background(.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GlassDatePicker: View {
    let title: String
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
            DatePicker(title, selection: $date, displayedComponents: .date)
                .colorScheme(.dark) // Picker'ı koyu moda zorla
        }
        .padding()
        .background(.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GlassButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(configuration.isPressed ? 0.6 : 0.8))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .animation(.spring, value: configuration.isPressed)
    }
}

struct GlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundStyle(.white)
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.2)))
            .animation(.spring, value: configuration.isPressed)
    }
}

#Preview {
    InvoiceDetailView(invoice: Invoice())
}

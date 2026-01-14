import SwiftUI
import SwiftData

// MARK: - Invoice List View

/// Kaydedilmiş fatura listesi görünümü (SwiftData ile)
/// - Aranabilir ve filtrelenebilir
/// - Swipe actions (delete)
/// - Hibrit Depolama: Thumbnail'ler async yüklenir
struct InvoiceListView: View {
    
    // MARK: - SwiftData Query
    
    /// Kaydedilmiş faturalar (tarih sırasına göre, en yeni önce)
    @Query(sort: \SavedInvoice.date, order: .reverse)
    private var savedInvoices: [SavedInvoice]
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var selectedInvoice: SavedInvoice?
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredInvoices.isEmpty {
                    emptyStateView
                } else {
                    invoiceList
                }
            }
            .navigationTitle("Faturalar")
            .searchable(text: $searchText, prompt: "Satıcı veya tutar ara...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .sheet(item: $selectedInvoice) { invoice in
                SavedInvoiceDetailView(savedInvoice: invoice)
            }
        }
    }
    
    // MARK: - Filtered Invoices
    
    private var filteredInvoices: [SavedInvoice] {
        var result = Array(savedInvoices)
        
        // Metin araması
        if !searchText.isEmpty {
            result = result.filter { invoice in
                invoice.supplierName?.localizedCaseInsensitiveContains(searchText) == true ||
                (invoice.totalAmount?.description.contains(searchText) == true)
            }
        }
        
        // Filtre
        switch selectedFilter {
        case .all:
            break
        case .thisMonth:
            let calendar = Calendar.current
            result = result.filter { invoice in
                guard let date = invoice.date else { return false }
                return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
            }
        case .highValue:
            result = result.filter { invoice in
                guard let amount = invoice.totalAmount else { return false }
                return amount >= 1000
            }
        }
        
        return result
    }
    
    // MARK: - Invoice List
    
    private var invoiceList: some View {
        List {
            ForEach(filteredInvoices) { invoice in
                SavedInvoiceRowView(invoice: invoice)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedInvoice = invoice
                    }
            }
            .onDelete(perform: deleteInvoices)
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    if selectedFilter == filter {
                        Label(filter.title, systemImage: "checkmark")
                    } else {
                        Text(filter.title)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            searchText.isEmpty ? "Henüz Fatura Yok" : "Sonuç Bulunamadı",
            systemImage: searchText.isEmpty ? "doc.text" : "magnifyingglass",
            description: Text(searchText.isEmpty ? "Fatura eklemek için Dashboard'dan tarama yapın" : "Arama kriterlerinizi değiştirin")
        )
    }
    
    // MARK: - Actions
    
    /// Fatura silme (Hibrit Depolama: Önce disk dosyasını sil, sonra veritabanı kaydını)
    private func deleteInvoices(at offsets: IndexSet) {
        for index in offsets {
            let invoice = filteredInvoices[index]
            
            // 1. Disk'teki görsel dosyasını sil (Hibrit Depolama)
            if let fileName = invoice.imageFileName {
                ImageStorageService.shared.delete(fileName: fileName)
            }
            
            // 2. Veritabanı kaydını sil
            modelContext.delete(invoice)
        }
    }
}

// MARK: - Invoice Filter

enum InvoiceFilter: CaseIterable {
    case all
    case thisMonth
    case highValue
    
    var title: String {
        switch self {
        case .all: return "Tümü"
        case .thisMonth: return "Bu Ay"
        case .highValue: return "1000₺+"
        }
    }
}

// MARK: - Saved Invoice Row View

struct SavedInvoiceRowView: View {
    let invoice: SavedInvoice
    
    /// Async yüklenen thumbnail
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (Hibrit Depolama: Disk'ten async yüklenir)
            thumbnailView
                .frame(width: 44, height: 44)
            
            // Bilgiler
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.supplierName ?? "Bilinmeyen Satıcı")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let date = invoice.date {
                        Text(date, format: .dateTime.day().month().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let invoiceNo = invoice.invoiceNumber {
                        Text(invoiceNo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Tutar
            if let amount = invoice.totalAmount {
                Text(amount, format: .currency(code: "TRY"))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadThumbnail()
        }
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Circle()
                .fill(invoice.isAutoAccepted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .overlay {
                    Image(systemName: invoice.isAutoAccepted ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(invoice.isAutoAccepted ? .green : .orange)
                }
        }
    }
    
    /// Thumbnail'ı disk'ten async yükler
    private func loadThumbnail() async {
        guard let fileName = invoice.imageFileName else { return }
        
        // Background thread'de yükle
        let image = await Task.detached(priority: .background) {
            ImageStorageService.shared.load(fileName: fileName)
        }.value
        
        await MainActor.run {
            self.thumbnail = image
        }
    }
}

// MARK: - Saved Invoice Detail View

struct SavedInvoiceDetailView: View {
    let savedInvoice: SavedInvoice
    
    @Environment(\.dismiss) private var dismiss
    @State private var invoiceImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Görsel Önizleme
                    imagePreview
                        .frame(height: 250)
                    
                    // Detay Formu
                    formContent
                }
                .padding()
            }
            .navigationTitle("Fatura Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadImage()
            }
        }
    }
    
    // MARK: - Image Preview
    
    @ViewBuilder
    private var imagePreview: some View {
        if let image = invoiceImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Görsel Bulunamadı")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Form Content
    
    private var formContent: some View {
        VStack(spacing: 16) {
            // Satıcı
            DetailRow(label: "Satıcı", value: savedInvoice.supplierName ?? "Bilinmiyor")
            
            // Tarih
            if let date = savedInvoice.date {
                DetailRow(label: "Tarih", value: date.formatted(date: .long, time: .omitted))
            }
            
            // Tutar
            if let amount = savedInvoice.totalAmount {
                DetailRow(label: "Toplam", value: amount.formatted(.currency(code: "TRY")))
            }
            
            // Fatura No
            if let invoiceNo = savedInvoice.invoiceNumber {
                DetailRow(label: "Fatura No", value: invoiceNo)
            }
            
            // ETTN
            if let ettn = savedInvoice.ettn {
                DetailRow(label: "ETTN", value: ettn)
                    .font(.caption)
            }
            
            // Durum
            HStack {
                Text("Durum")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: savedInvoice.isAutoAccepted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    Text(savedInvoice.isAutoAccepted ? "Otomatik Onaylandı" : "Manuel İnceleme")
                }
                .foregroundStyle(savedInvoice.isAutoAccepted ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Görseli disk'ten async yükler
    private func loadImage() async {
        guard let fileName = savedInvoice.imageFileName else { return }
        
        let image = await Task.detached(priority: .background) {
            ImageStorageService.shared.load(fileName: fileName)
        }.value
        
        await MainActor.run {
            self.invoiceImage = image
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    InvoiceListView()
        .modelContainer(for: SavedInvoice.self, inMemory: true)
}

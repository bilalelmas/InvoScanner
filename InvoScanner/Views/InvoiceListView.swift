import SwiftUI
import SwiftData

// MARK: - Fatura Listesi

/// Tüm faturaların listelendiği cam efektli ekran
struct InvoiceListView: View {
    
    /// Veritabanı sorgusu (Tarihe göre ters sıralı)
    @Query(sort: \SavedInvoice.date, order: .reverse)
    private var savedInvoices: [SavedInvoice]
    
    @Environment(\.modelContext) private var modelContext
    
    // Filtreleme ve arama durumları
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var selectedInvoice: SavedInvoice?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Kristal arka plan
                CrystalBackground()
                
                // İçerik hiyerarşisi
                VStack(spacing: 0) {
                    // Özel arama çubuğu
                    glassSearchBar
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Filtreleme seçenekleri
                    Picker("Filtre", selection: $selectedFilter) {
                        ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Liste veya boş durum
                    if filteredInvoices.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            ForEach(filteredInvoices) { invoice in
                                InvoiceItemView(invoice: invoice)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .onTapGesture {
                                        selectedInvoice = invoice
                                    }
                            }
                            .onDelete(perform: deleteInvoices)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Faturalar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $selectedInvoice) { invoice in
                SavedInvoiceDetailView(savedInvoice: invoice)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - Silme İşlemi
    
    private func deleteInvoices(at offsets: IndexSet) {
        for index in offsets {
            let invoice = filteredInvoices[index]
            deleteInvoice(invoice)
        }
    }
    
    // MARK: - Alt Bileşenler
    
    /// Cam efektli arama çubuğu
    private var glassSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
            
            TextField("Satıcı veya tutar ara...", text: $searchText)
                .foregroundStyle(.white)
                .tint(.cyan)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    /// Liste satırı (Görsel yükleme yönetimiyle)
    struct InvoiceItemView: View {
        let invoice: SavedInvoice
        @State private var thumbnail: UIImage?
        
        var body: some View {
            GlassInvoiceRow(
                supplierName: invoice.supplierName ?? "Bilinmeyen Satıcı",
                totalAmount: invoice.totalAmount,
                date: invoice.date,
                isVerified: invoice.isAutoAccepted,
                thumbnail: thumbnail
            )
            .task {
                await loadThumbnail()
            }
        }
        
        /// Diskten küçük resmi yükler
        private func loadThumbnail() async {
            guard let fileName = invoice.imageFileName else { return }
            let image = await Task.detached(priority: .background) {
                await ImageStorageService.shared.load(fileName: fileName)
            }.value
            await MainActor.run { self.thumbnail = image }
        }
    }
    
    /// Veri yoksa veya arama sonucu boşsa gösterilir
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(searchText.isEmpty ? "Henüz Fatura Yok" : "Sonuç Bulunamadı")
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
        }
    }
    
    // MARK: - Mantıksal Filtreleme
    
    /// Arama ve kategori filtrelerini uygulayan liste
    private var filteredInvoices: [SavedInvoice] {
        var result = Array(savedInvoices)
        
        if !searchText.isEmpty {
            result = result.filter { invoice in
                invoice.supplierName?.localizedCaseInsensitiveContains(searchText) == true ||
                (invoice.totalAmount?.description.contains(searchText) == true)
            }
        }
        
        switch selectedFilter {
        case .all: break
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
    
    /// Faturayı ve ilişkili görseli siler
    private func deleteInvoice(_ invoice: SavedInvoice) {
        if let fileName = invoice.imageFileName {
            ImageStorageService.shared.delete(fileName: fileName)
        }
        modelContext.delete(invoice)
    }
}

// MARK: - Filtre Seçenekleri

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

import SwiftUI
import SwiftData

// MARK: - Invoice List View (Neo-Glass)

/// Fatura listesi - Crystal UI
/// - List yerine ScrollView + LazyVStack
/// - Özel Cam Arama Çubuğu
struct InvoiceListView: View {
    
    // MARK: - SwiftData Query
    @Query(sort: \SavedInvoice.date, order: .reverse)
    private var savedInvoices: [SavedInvoice]
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var selectedInvoice: SavedInvoice?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Arka Plan
                CrystalBackground()
                
                // 2. İçerik
                VStack(spacing: 0) {
                    // Custom Search Bar
                    glassSearchBar
                        .padding()
                    
                    // Filtreleme Segmentleri (İsteğe bağlı, şimdilik menüde)
                    
                    if filteredInvoices.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredInvoices) { invoice in
                                    InvoiceItemView(invoice: invoice)
                                        .onTapGesture {
                                            selectedInvoice = invoice
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteInvoice(invoice)
                                            } label: {
                                                Label("Sil", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding()
                            .padding(.bottom, 80) // TabBar payı
                        }
                    }
                }
            }
            .navigationTitle("Faturalar")
            .navigationBarTitleDisplayMode(.large) // Large title şeffaflıkla güzel durur
            .toolbarBackground(.hidden, for: .navigationBar) // Navigation bar şeffaf
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenuButton
                }
            }
            .sheet(item: $selectedInvoice) { invoice in
                SavedInvoiceDetailView(savedInvoice: invoice)
                    .presentationBackground(.ultraThinMaterial) // Cam Sheet
            }
        }
    }
    
    // MARK: - Components
    
    private var glassSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
            
            TextField("Satıcı veya tutar ara...", text: $searchText)
                .foregroundStyle(.white)
                .tint(.cyan) // İmleç rengi
            
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
    
    // Yardımcı View: Thumbnail yükleme lojistiğini yönetir
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
        
        private func loadThumbnail() async {
            guard let fileName = invoice.imageFileName else { return }
            let image = await Task.detached(priority: .background) {
                ImageStorageService.shared.load(fileName: fileName)
            }.value
            await MainActor.run { self.thumbnail = image }
        }
    }
    
    private var filterMenuButton: some View {
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
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .font(.title2)
        }
    }
    
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
    
    // MARK: - Logic
    
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
    
    private func deleteInvoice(_ invoice: SavedInvoice) {
        if let fileName = invoice.imageFileName {
            ImageStorageService.shared.delete(fileName: fileName)
        }
        modelContext.delete(invoice)
    }
}

// Filter enum aynı kalıyor
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

#Preview {
    InvoiceListView()
        .modelContainer(for: SavedInvoice.self, inMemory: true)
}

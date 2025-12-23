import SwiftUI

// MARK: - Invoice List View

/// Fatura listesi görünümü
/// - Aranabilir ve filtrelenebilir
/// - Swipe actions (delete, share)
struct InvoiceListView: View {
    
    @State private var searchText = ""
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var invoices: [Invoice] = [] // TODO: SwiftData'dan gelecek
    @State private var selectedInvoice: Invoice?
    
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
                InvoiceDetailView(invoice: invoice)
            }
        }
    }
    
    // MARK: - Filtered Invoices
    
    private var filteredInvoices: [Invoice] {
        var result = invoices
        
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
        
        return result.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
    
    // MARK: - Invoice List
    
    private var invoiceList: some View {
        List {
            ForEach(filteredInvoices) { invoice in
                InvoiceRowView(invoice: invoice)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedInvoice = invoice
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteInvoice(invoice)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        ShareLink(item: formatInvoiceForShare(invoice)) {
                            Label("Paylaş", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
            }
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
    
    private func deleteInvoice(_ invoice: Invoice) {
        invoices.removeAll { $0.id == invoice.id }
    }
    
    private func formatInvoiceForShare(_ invoice: Invoice) -> String {
        """
        📄 Fatura Bilgisi
        Satıcı: \(invoice.supplierName ?? "Bilinmiyor")
        Tarih: \(invoice.date?.formatted(date: .numeric, time: .omitted) ?? "Bilinmiyor")
        Tutar: \(invoice.totalAmount?.formatted(.currency(code: "TRY")) ?? "Bilinmiyor")
        ETTN: \(invoice.ettn?.uuidString ?? "N/A")
        """
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

// MARK: - Invoice Row View

struct InvoiceRowView: View {
    let invoice: Invoice
    
    var body: some View {
        HStack(spacing: 12) {
            // İkon
            Circle()
                .fill(invoice.isAutoAccepted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: invoice.isAutoAccepted ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(invoice.isAutoAccepted ? .green : .orange)
                }
            
            // Bilgiler
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.supplierName ?? "Bilinmeyen Satıcı")
                    .font(.headline)
                
                if let date = invoice.date {
                    Text(date, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    }
}

// MARK: - Preview

#Preview {
    InvoiceListView()
}

import Foundation
import SwiftUI
import SwiftData

// MARK: - Yükleme Durumu

/// Dashboard veri yükleme durumları
enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
    
    /// Yükleme devam ediyor mu?
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - İstatistikler

/// Dashboard istatistik verileri
struct DashboardStats {
    var totalInvoiceCount: Int = 0
    var monthlySpend: Decimal = 0
    var previousMonthSpend: Decimal = 0
    var categoryBreakdown: [String: Decimal] = [:]
    var monthlyTrend: [MonthlyData] = []
    
    /// Geçen aya göre harcama değişimi (%)
    var monthOverMonthChange: Double {
        guard previousMonthSpend > 0 else { return 0 }
        let change = (monthlySpend - previousMonthSpend) / previousMonthSpend
        return NSDecimalNumber(decimal: change).doubleValue * 100
    }
    
    /// Veri bulunmuyor mu?
    var isEmpty: Bool {
        totalInvoiceCount == 0
    }
}

/// Grafik verisi (Aylık)
struct MonthlyData: Identifiable {
    let id = UUID()
    let month: String
    let amount: Decimal
}

// MARK: - Dashboard ViewModel

/// Dashboard verilerini yöneten ViewModel
@Observable
final class DashboardViewModel {
    
    // MARK: - Durum
    
    var loadState: LoadState = .idle
    var stats: DashboardStats = DashboardStats()
    
    // MARK: - Hesaplanan Özellikler
    
    var isLoading: Bool { loadState.isLoading }
    var isEmpty: Bool { stats.isEmpty && loadState == .loaded }
    
    var errorMessage: String? {
        if case .error(let message) = loadState {
            return message
        }
        return nil
    }
    
    // MARK: - Fonksiyonlar
    
    /// İstatistikleri hesaplar ve verileri yükler
    @MainActor
    func loadData(context: ModelContext) async {
        loadState = .loading
        
        do {
            // Tüm faturaları çek
            let descriptor = FetchDescriptor<SavedInvoice>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let invoices = try context.fetch(descriptor)
            
            let totalCount = invoices.count
            
            // Mevcut ayın verileri
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            
            let thisMonthInvoices = invoices.filter {
                guard let date = $0.date else { return false }
                return date >= startOfMonth
            }
            
            let monthlySpend = thisMonthInvoices.reduce(Decimal(0)) { $0 + ($1.totalAmount ?? 0) }
            
            // Geçen ayın verileri
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
            let endOfLastMonth = startOfMonth
            
            let lastMonthInvoices = invoices.filter {
                guard let date = $0.date else { return false }
                return date >= startOfLastMonth && date < endOfLastMonth
            }
            
            let previousMonthSpend = lastMonthInvoices.reduce(Decimal(0)) { $0 + ($1.totalAmount ?? 0) }
            
            // Aylık Trend
            let trend: [MonthlyData] = []
            
            // Kategori dağılımı (Satıcı bazlı)
            var categoryBreakdown: [String: Decimal] = [:]
            for invoice in thisMonthInvoices {
                let supplier = invoice.supplierName ?? "Diğer"
                categoryBreakdown[supplier, default: 0] += (invoice.totalAmount ?? 0)
            }
            
            // State güncelleme
            self.stats = DashboardStats(
                totalInvoiceCount: totalCount,
                monthlySpend: monthlySpend,
                previousMonthSpend: previousMonthSpend,
                categoryBreakdown: categoryBreakdown,
                monthlyTrend: trend
            )
            
            loadState = .loaded
            
        } catch {
            print("DashboardViewModel Hatası: \(error)")
            loadState = .error("Veriler yüklenirken hata oluştu.")
        }
    }
    
    /// Verileri yeniden yükle
    @MainActor
    func retry(context: ModelContext) async {
        await loadData(context: context)
    }
}

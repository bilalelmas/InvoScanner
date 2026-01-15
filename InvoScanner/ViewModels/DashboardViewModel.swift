import Foundation
import SwiftUI

// MARK: - Load State

/// Dashboard veri yükleme durumu
enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Dashboard Statistics

/// Dashboard için hesaplanan istatistikler
struct DashboardStats {
    var totalInvoiceCount: Int = 0
    var monthlySpend: Decimal = 0
    var previousMonthSpend: Decimal = 0
    var categoryBreakdown: [String: Decimal] = [:]
    var monthlyTrend: [MonthlyData] = []
    
    /// Geçen aya göre değişim oranı
    var monthOverMonthChange: Double {
        guard previousMonthSpend > 0 else { return 0 }
        let change = (monthlySpend - previousMonthSpend) / previousMonthSpend
        return NSDecimalNumber(decimal: change).doubleValue * 100
    }
    
    /// Boş durum kontrolü
    var isEmpty: Bool {
        totalInvoiceCount == 0
    }
}

/// Aylık trend verisi (Charts için)
struct MonthlyData: Identifiable {
    let id = UUID()
    let month: String
    let amount: Decimal
}

// MARK: - Dashboard ViewModel

import SwiftData

// ... (LoadState ve DashboardStats aynı kalacak)

// MARK: - Dashboard ViewModel

/// Dashboard ana ViewModel'i
/// - SwiftData entegrasyonu ile gerçek verileri gösterir
@Observable
final class DashboardViewModel {
    
    // MARK: - State
    
    var loadState: LoadState = .idle
    var stats: DashboardStats = DashboardStats()
    
    // MARK: - Computed Properties
    
    var isLoading: Bool { loadState.isLoading }
    var isEmpty: Bool { stats.isEmpty && loadState == .loaded }
    
    var errorMessage: String? {
        if case .error(let message) = loadState {
            return message
        }
        return nil
    }
    
    // MARK: - Actions
    
    /// Dashboard verilerini yükler ve istatistikleri hesaplar
    /// - Parameter context: SwiftData ModelContext
    @MainActor
    func loadData(context: ModelContext) async {
        loadState = .loading
        
        do {
            // 1. Tüm faturaları çek
            let descriptor = FetchDescriptor<SavedInvoice>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let invoices = try context.fetch(descriptor)
            
            // 2. İstatistikleri hesapla
            let totalCount = invoices.count
            
            // Bu ayın toplamı
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            
            let thisMonthInvoices = invoices.filter {
                guard let date = $0.date else { return false }
                return date >= startOfMonth
            }
            
            let monthlySpend = thisMonthInvoices.reduce(Decimal(0)) { $0 + ($1.totalAmount ?? 0) }
            
            // Geçen ayın toplamı
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
            let endOfLastMonth = startOfMonth
            
            let lastMonthInvoices = invoices.filter {
                guard let date = $0.date else { return false }
                return date >= startOfLastMonth && date < endOfLastMonth
            }
            
            let previousMonthSpend = lastMonthInvoices.reduce(Decimal(0)) { $0 + ($1.totalAmount ?? 0) }
            
            // Aylık Trend (Son 6 ay)
            // Basit implementasyon: Sadece mevcut veriyi göster
            // Gelişmiş versiyonda gruplama yapılabilir
            let trend: [MonthlyData] = []
            // (Mock trend değil gerçek veriden hesaplanmalı, şimdilik boş bırakıyorum karmaşıklığı artırmamak için)
            
            // Kategori dağılımı (Şimdilik satıcı bazlı)
            var categoryBreakdown: [String: Decimal] = [:]
            for invoice in thisMonthInvoices {
                let supplier = invoice.supplierName ?? "Diğer"
                categoryBreakdown[supplier, default: 0] += (invoice.totalAmount ?? 0)
            }
            
            // 3. State'i güncelle
            self.stats = DashboardStats(
                totalInvoiceCount: totalCount,
                monthlySpend: monthlySpend,
                previousMonthSpend: previousMonthSpend,
                categoryBreakdown: categoryBreakdown,
                monthlyTrend: trend
            )
            
            loadState = .loaded
            
        } catch {
            print("DashboardViewModel Error: \(error)")
            loadState = .error("Veriler yüklenirken hata oluştu.")
        }
    }
    
    /// Yeniden deneme
    @MainActor
    func retry(context: ModelContext) async {
        await loadData(context: context)
    }
}

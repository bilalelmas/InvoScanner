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

/// Dashboard ana ViewModel'i
/// - @Observable: iOS 17+ modern state management
@Observable
final class DashboardViewModel {
    
    // MARK: - State
    
    var loadState: LoadState = .idle
    var stats: DashboardStats = DashboardStats()
    var recentInvoices: [Invoice] = []
    
    // MARK: - Computed Properties
    
    /// Yükleme göstergesi için
    var isLoading: Bool { loadState.isLoading }
    
    /// Boş durum kontrolü
    var isEmpty: Bool { stats.isEmpty && loadState == .loaded }
    
    /// Hata mesajı
    var errorMessage: String? {
        if case .error(let message) = loadState {
            return message
        }
        return nil
    }
    
    // MARK: - Actions
    
    /// Dashboard verilerini yükler
    @MainActor
    func loadData() async {
        loadState = .loading
        
        do {
            // Simüle edilen veri yükleme (gerçekte SwiftData'dan gelecek)
            try await Task.sleep(for: .milliseconds(500))
            
            // Mock data (Phase 3'te gerçek veriyle değiştirilecek)
            stats = DashboardStats(
                totalInvoiceCount: 0, // Başlangıçta boş
                monthlySpend: 0,
                previousMonthSpend: 0,
                categoryBreakdown: [:],
                monthlyTrend: []
            )
            
            loadState = .loaded
        } catch {
            loadState = .error("Veriler yüklenirken hata oluştu: \(error.localizedDescription)")
        }
    }
    
    /// Yeniden deneme
    @MainActor
    func retry() async {
        await loadData()
    }
}

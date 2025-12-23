import SwiftUI
import Charts

// MARK: - Dashboard View

/// Ana Dashboard ekranı
/// - Modern iOS 17+ tasarım
/// - SwiftCharts entegrasyonu
/// - LoadState yönetimi
struct DashboardView: View {
    
    @State private var viewModel = DashboardViewModel()
    @State private var showScanner = false
    @State private var showGallery = false
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    loadingView
                case .loaded:
                    if viewModel.isEmpty {
                        emptyStateView
                    } else {
                        dashboardContent
                    }
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("InvoScanner")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showScanner = true }) {
                            Label("Kamera ile Tara", systemImage: "camera")
                        }
                        Button(action: { showGallery = true }) {
                            Label("Galeriden Seç", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showScanner) {
                // DocumentCameraView entegrasyonu yapılacak
                Text("Kamera Tarayıcı")
            }
        }
    }
    
    // MARK: - Dashboard Content
    
    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Özet Kartları
                summaryCards
                
                // Harcama Trendi (Chart)
                if !viewModel.stats.monthlyTrend.isEmpty {
                    spendingTrendChart
                }
                
                // Kategori Dağılımı (Pie Chart)
                if !viewModel.stats.categoryBreakdown.isEmpty {
                    categoryPieChart
                }
                
                // Hızlı Aksiyonlar
                quickActions
            }
            .padding()
        }
    }
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCardView(
                title: "Toplam Fatura",
                value: "\(viewModel.stats.totalInvoiceCount)",
                icon: "doc.text",
                color: .blue
            )
            
            StatCardView(
                title: "Bu Ay",
                value: viewModel.stats.monthlySpend.formatted(.currency(code: "TRY")),
                icon: "banknote",
                color: .green,
                badge: formatChange(viewModel.stats.monthOverMonthChange)
            )
        }
    }
    
    // MARK: - Charts
    
    private var spendingTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Harcama Trendi")
                .font(.headline)
            
            Chart(viewModel.stats.monthlyTrend) { data in
                LineMark(
                    x: .value("Ay", data.month),
                    y: .value("Tutar", data.amount)
                )
                .foregroundStyle(.blue.gradient)
                
                AreaMark(
                    x: .value("Ay", data.month),
                    y: .value("Tutar", data.amount)
                )
                .foregroundStyle(.blue.opacity(0.1))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var categoryPieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategori Dağılımı")
                .font(.headline)
            
            Chart(Array(viewModel.stats.categoryBreakdown), id: \.key) { category in
                SectorMark(
                    angle: .value("Tutar", category.value),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Kategori", category.key))
            }
            .frame(height: 200)
            .chartLegend(position: .bottom)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hızlı İşlemler")
                .font(.headline)
            
            HStack(spacing: 16) {
                QuickActionButtonView(
                    title: "Tara",
                    icon: "camera.fill",
                    color: .blue
                ) {
                    showScanner = true
                }
                
                QuickActionButtonView(
                    title: "Galeri",
                    icon: "photo.fill",
                    color: .purple
                ) {
                    showGallery = true
                }
                
                QuickActionButtonView(
                    title: "PDF",
                    icon: "doc.fill",
                    color: .orange
                ) {
                    // PDF picker
                }
            }
        }
    }
    
    // MARK: - States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Yükleniyor...")
                .foregroundStyle(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "Henüz Fatura Yok",
            systemImage: "doc.text.magnifyingglass",
            description: Text("İlk faturanızı taramak için + butonuna dokunun")
        )
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Hata Oluştu")
                .font(.title2.bold())
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Tekrar Dene") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func formatChange(_ change: Double) -> String? {
        guard change != 0 else { return nil }
        let prefix = change > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", change))%"
    }
}

// MARK: - Stat Card View

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var badge: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badge.hasPrefix("+") ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            
            Text(value)
                .font(.title2.bold())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Action Button View

struct QuickActionButtonView: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Preview

#Preview("Dashboard - Loaded") {
    DashboardView()
}

#Preview("Dashboard - Empty") {
    DashboardView()
}

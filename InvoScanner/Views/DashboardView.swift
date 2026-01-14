import SwiftUI
import Charts
import SwiftData

// MARK: - Dashboard View (Neo-Glass)

/// Ana Dashboard ekranı - Crystal UI
/// - Floating HUD konsepti
/// - SwiftCharts ile neon grafikler
/// - Glassmorphism kartlar
struct DashboardView: View {
    
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    @State private var showScanner = false
    @State private var showGallery = false
    
    var body: some View {
        ZStack {
            // 1. Dinamik Arka Plan
            CrystalBackground()
            
            // 2. İçerik
            ScrollView {
                VStack(spacing: 24) {
                    
                    headerSection
                    
                    if viewModel.isLoading {
                        loadingView
                    } else if !viewModel.isEmpty {
                        
                        // Ana Kart (Toplam Harcama)
                        mainStatsCard
                        
                        // İstatistik Izgarası
                        statsGrid
                        
                        // Son İşlemler
                        recentActivitySection
                        
                    } else {
                        emptyStateView
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                .padding(.bottom, 100) // TabBar için boşluk
            }
            .refreshable {
                await viewModel.loadData(context: modelContext)
            }
        }
        .task {
            // Verileri yükle
            await viewModel.loadData(context: modelContext)
        }
        .sheet(isPresented: $showScanner) {
            // Scanner View entegrasyonu (Placeholder)
            ZStack {
                CrystalBackground()
                Text("Kamera Modu Aktif")
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("İyi Akşamlar,")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Bilal Elmas")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            
            // Profil İkonu
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.8))
                .background(Circle().fill(.white.opacity(0.1)))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
    }
    
    private var mainStatsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Bu Ay Toplam")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                    
                    Text(viewModel.stats.monthlySpend.formatted(.currency(code: "TRY")))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                Spacer()
                
                // Artış/Azalış Rozeti
                if viewModel.stats.monthOverMonthChange != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.stats.monthOverMonthChange > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%.1f%%", abs(viewModel.stats.monthOverMonthChange)))
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.stats.monthOverMonthChange > 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
            
            // Neon Grafik
            Chart {
                ForEach(viewModel.stats.monthlyTrend) { data in
                    LineMark(
                        x: .value("Ay", data.month),
                        y: .value("Tutar", data.amount)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                    
                    AreaMark(
                        x: .value("Ay", data.month),
                        y: .value("Tutar", data.amount)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
            .frame(height: 120)
            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.5)) } }
            .chartYAxis(.hidden)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private var statsGrid: some View {
        HStack(spacing: 16) {
            GlassStatCard(
                title: "Fatura Adedi",
                value: "\(viewModel.stats.totalInvoiceCount)",
                icon: "doc.text.fill",
                color: .indigo
            )
            
            GlassStatCard(
                title: "Ortalama",
                value: calculateAverage(),
                icon: "chart.bar.fill",
                color: .purple
            )
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Son İşlemler")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button("Tümü") {
                    // Navigate to list
                }
                .font(.subheadline)
                .foregroundStyle(.cyan)
            }
            
            if !viewModel.stats.isEmpty {
                // Not: DashboardViewModel'de recentInvoices eksik olabilir, 
                // şimdilik sadece görsel test için dummy loop veya viewModel desteği gerek
                // V6.0: ViewModel'e recentInvoices eklenmeli veya buradan sorgu yapılmalı
                // Şimdilik listeye yönlendirme butonu var, burası boş kalmasın diye statik bir mesaj
                
                GlassInvoiceRow(
                    supplierName: "Son eklenen faturalar",
                    totalAmount: nil,
                    date: Date(),
                    isVerified: true
                )
                .opacity(0.5)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 70))
                .foregroundStyle(.white.opacity(0.5))
            
            Text("Henüz Fatura Yok")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("İlk faturanızı eklemek için +'ya basın")
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .frame(height: 300)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
        }
        .frame(height: 200)
    }
    
    // MARK: - Helpers
    
    private func calculateAverage() -> String {
        guard viewModel.stats.totalInvoiceCount > 0 else { return "₺0" }
        let avg = NSDecimalNumber(decimal: viewModel.stats.monthlySpend).doubleValue / Double(viewModel.stats.totalInvoiceCount)
        return String(format: "₺%.0f", avg)
    }
}

// MARK: - Glass Stat Card

struct GlassStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.gradient)
                    .padding(8)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    DashboardView()
}

import SwiftUI
import Charts
import SwiftData

// MARK: - Dashboard Ekranı

/// Kristal tasarım diline sahip ana gösterge paneli
struct DashboardView: View {
    
    @Environment(\.modelContext) private var modelContext
    
    /// Veritabanındaki tüm faturalar (Tarihe göre sıralı)
    @Query(sort: \SavedInvoice.createdAt, order: .reverse) 
    private var allInvoices: [SavedInvoice]
    
    @State private var viewModel = DashboardViewModel()
    
    // Navigasyon durumları
    @State private var showScanner = false
    @State private var showGallery = false
    @State private var selectedInvoice: SavedInvoice?
    
    var body: some View {
        ZStack {
            // Dinamik Aurora arka plan
            CrystalBackground()
            
            // Kaydırılabilir içerik
            ScrollView {
                VStack(spacing: 24) {
                    
                    headerSection
                    
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        // İstatistik kartları ve grafikler
                        if !allInvoices.isEmpty {
                            mainStatsCard
                            statsGrid
                        } else {
                            // Boş durum (Empty State)
                            emptyStateView
                        }
                        
                        // Son işlemler listesi
                        if !allInvoices.isEmpty {
                            recentActivitySection
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .refreshable {
                await viewModel.loadData(context: modelContext)
            }
            
            // Fatura Ekle butonu (FAB)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .shadow(color: .cyan.opacity(0.5), radius: 10, x: 0, y: 5)
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .task {
            // Verileri yükle
            await viewModel.loadData(context: modelContext)
        }
        .fullScreenCover(isPresented: $showScanner) {
            ScannerView()
        }
        .sheet(item: $selectedInvoice) { invoice in
            SavedInvoiceDetailView(savedInvoice: invoice)
                .presentationBackground(.ultraThinMaterial)
        }
    }
    
    // MARK: - Alt Bileşenler
    
    /// Üst bilgi ve profil bölümü
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
            
            // Profil ikonu
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.8))
                .background(Circle().fill(.white.opacity(0.1)))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
    }
    
    /// Ana harcama istatistiği ve neon grafik
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
                
                // Aylık değişim göstergesi
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
            
            // Neon çizgi grafik
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
    
    /// Adet ve ortalama kartları
    private var statsGrid: some View {
        HStack(spacing: 16) {
            GlassStatCard(
                title: "Fatura Adedi",
                value: "\(allInvoices.count)",
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
    
    /// Son kaydedilen faturalar
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Son İşlemler")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(allInvoices.count) fatura")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Son 10 işlem
            ForEach(allInvoices.prefix(10)) { invoice in
                InvoiceItemRow(invoice: invoice)
                    .onTapGesture {
                        selectedInvoice = invoice
                    }
            }
        }
    }
    
    /// Veri bulunmadığında gösterilen ekran
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 70))
                .foregroundStyle(.white.opacity(0.5))
            
            Text("Henüz Fatura Yok")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Yeni eklemek için sağ alttaki + butonuna basın")
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(height: 300)
    }
    
    /// Yükleme halkası
    private var loadingView: some View {
        VStack {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
        }
        .frame(height: 200)
    }
    
    // MARK: - Yardımcı Yapılar
    
    /// Fatura listesi satırı (Görsel yükleme destekli)
    struct InvoiceItemRow: View {
        let invoice: SavedInvoice
        @State private var thumbnail: UIImage?
        
        var body: some View {
            GlassInvoiceRow(
                supplierName: invoice.supplierName ?? "Bilinmiyor",
                totalAmount: invoice.totalAmount,
                date: invoice.date,
                isVerified: invoice.isAutoAccepted,
                thumbnail: thumbnail
            )
            .task {
                if let fileName = invoice.imageFileName {
                    let image = await Task.detached(priority: .background) {
                        await ImageStorageService.shared.load(fileName: fileName)
                    }.value
                    await MainActor.run { self.thumbnail = image }
                }
            }
        }
    }
    
    /// Ortalama fatura tutarı hesaplama
    private func calculateAverage() -> String {
        guard !allInvoices.isEmpty else { return "₺0" }
        let total = allInvoices.reduce(0) { $0 + (NSDecimalNumber(decimal: $1.totalAmount ?? 0).doubleValue) }
        let avg = total / Double(allInvoices.count)
        return String(format: "₺%.0f", avg)
    }
}

// MARK: - Cam İstatistik Kartı

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

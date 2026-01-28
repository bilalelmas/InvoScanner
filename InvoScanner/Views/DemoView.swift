import SwiftUI

// MARK: - Demo Test View

/// Fatura veri çıkarma doğruluk testi ekranı
struct DemoView: View {
    @StateObject private var viewModel = DemoViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                CrystalBackground()
                
                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.testResults) { result in
                                TestResultCard(result: result)
                            }
                        }
                        .padding()
                    }
                    
                    startButton
                }
            }
            .navigationTitle("🧪 Demo Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Fatura \(viewModel.currentTestIndex + 1)/\(viewModel.testResults.count) test ediliyor...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if viewModel.overallSuccessRate > 0 {
                Text("\(Int(viewModel.overallSuccessRate * 100))%")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.overallSuccessRate >= 0.8 ? .green : .orange)
                
                Text("Doğruluk Oranı")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                // Özet istatistikler
                HStack(spacing: 20) {
                    statItem(value: viewModel.testResults.count, label: "Test")
                    statItem(value: viewModel.testResults.reduce(0) { $0 + $1.matchCount }, label: "Eşleşme")
                    statItem(value: viewModel.testResults.count * 4, label: "Toplam Alan")
                }
                .padding(.top, 8)
            } else {
                Image(systemName: "testtube.2")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Demo Test")
                    .font(.title2.bold())
                
                Text("\(viewModel.testResults.count) fatura test edilecek")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
    
    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Start Button
    
    private var startButton: some View {
        Button {
            Task {
                await viewModel.runAllTests()
            }
        } label: {
            HStack {
                Image(systemName: viewModel.isLoading ? "hourglass" : "play.fill")
                Text(viewModel.isLoading ? "Test Devam Ediyor..." : "Testi Başlat")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isLoading ? Color.gray : Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(viewModel.isLoading)
        .padding()
    }
}

// MARK: - Test Result Card

struct TestResultCard: View {
    let result: DemoViewModel.DemoTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Fatura \(result.id)")
                    .font(.headline)
                
                Spacer()
                
                if result.isComplete {
                    HStack(spacing: 4) {
                        Text("\(result.matchCount)/5")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(result.successRate * 100))%")
                            .font(.title3.bold())
                            .foregroundStyle(result.successRate >= 0.75 ? .green : .orange)
                    }
                }
            }
            
            if result.isComplete, let extracted = result.extracted {
                Divider()
                
                // Beklenen vs Çıkarılan karşılaştırması
                VStack(spacing: 8) {
                    comparisonRow(
                        field: "ETTN",
                        expected: result.expected.ettn,
                        extracted: extracted.ettn ?? "-",
                        isMatch: result.ettnMatch
                    )
                    
                    comparisonRow(
                        field: "Fatura No",
                        expected: result.expected.invoiceNumber,
                        extracted: extracted.invoiceNumber ?? "-",
                        isMatch: result.invoiceNumberMatch
                    )
                    
                    comparisonRow(
                        field: "Satıcı",
                        expected: result.expected.supplierName,
                        extracted: extracted.supplierName ?? "-",
                        isMatch: result.supplierMatch
                    )
                    
                    comparisonRow(
                        field: "Tutar",
                        expected: formatAmount(result.expected.totalAmount),
                        extracted: extracted.totalAmount.map { formatDecimal($0) } ?? "-",
                        isMatch: result.amountMatch
                    )
                    
                    comparisonRow(
                        field: "Tarih",
                        expected: result.expected.date,
                        extracted: extracted.date ?? "-",
                        isMatch: result.dateMatch
                    )
                }
            } else if !result.isComplete {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Bekliyor...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func comparisonRow(field: String, expected: String, extracted: String, isMatch: Bool) -> some View {
        HStack(spacing: 8) {
            Text(field)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Beklenen:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(expected)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Text("Çıkarılan:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(extracted)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isMatch ? .green : .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(isMatch ? .green : .red)
        }
        .padding(.vertical, 4)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.currencySymbol = "₺"
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    private func formatDecimal(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.currencySymbol = "₺"
        return formatter.string(from: decimal as NSDecimalNumber) ?? "\(decimal)"
    }
}

#Preview {
    DemoView()
}

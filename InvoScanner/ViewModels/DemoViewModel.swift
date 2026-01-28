import Foundation
import Combine

// MARK: - Demo ViewModel

/// Fatura veri çıkarma doğruluk testi yönetimi
@MainActor
class DemoViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var testResults: [DemoTestResult] = []
    @Published var isLoading = false
    @Published var currentTestIndex = 0
    @Published var overallSuccessRate: Double = 0
    
    // MARK: - Test Data Model
    
    struct ExpectedInvoice: Codable {
        let ettn: String
        let invoiceNumber: String
        let supplierName: String
        let totalAmount: Double
        let date: String
    }
    
    struct TestInvoice: Codable {
        let id: Int
        let fileName: String
        let expected: ExpectedInvoice
    }
    
    struct GoldenTestData: Codable {
        let testInvoices: [TestInvoice]
    }
    
    // MARK: - Result Model
    
    struct DemoTestResult: Identifiable {
        let id: Int
        let fileName: String
        let expected: ExpectedInvoice
        var extracted: ExtractedData?
        var isComplete: Bool = false
        
        struct ExtractedData {
            let ettn: String?
            let invoiceNumber: String?
            let supplierName: String?
            let totalAmount: Decimal?
            let date: String?
        }
        
        var ettnMatch: Bool {
            guard let extracted = extracted?.ettn else { return false }
            return extracted.uppercased() == expected.ettn.uppercased()
        }
        
        var invoiceNumberMatch: Bool {
            guard let extracted = extracted?.invoiceNumber else { return false }
            return extracted.uppercased() == expected.invoiceNumber.uppercased()
        }
        
        var supplierMatch: Bool {
            guard let extracted = extracted?.supplierName else { return false }
            let expectedFirst = expected.supplierName.components(separatedBy: " ").first?.uppercased() ?? ""
            let extractedFirst = extracted.components(separatedBy: " ").first?.uppercased() ?? ""
            return extractedFirst == expectedFirst || extracted.uppercased().contains(expectedFirst)
        }
        
        var amountMatch: Bool {
            guard let extracted = extracted?.totalAmount else { return false }
            let expectedDecimal = Decimal(expected.totalAmount)
            return abs(NSDecimalNumber(decimal: extracted - expectedDecimal).doubleValue) < 0.01
        }
        
        var dateMatch: Bool {
            guard let extracted = extracted?.date else { return false }
            return extracted == expected.date
        }
        
        var matchCount: Int {
            [ettnMatch, invoiceNumberMatch, supplierMatch, amountMatch, dateMatch].filter { $0 }.count
        }
        
        var successRate: Double {
            Double(matchCount) / 5.0
        }
    }
    
    // MARK: - Initialization
    
    private let spatialParser = SpatialParser()
    
    init() {
        loadTestData()
    }
    
    // MARK: - Load Test Data
    
    func loadTestData() {
        guard let url = Bundle.main.url(forResource: "GoldenTestData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let goldenData = try? JSONDecoder().decode(GoldenTestData.self, from: data) else {
            print("⚠️ GoldenTestData.json yüklenemedi")
            return
        }
        
        testResults = goldenData.testInvoices.map { invoice in
            DemoTestResult(
                id: invoice.id,
                fileName: invoice.fileName,
                expected: invoice.expected
            )
        }
    }
    
    // MARK: - Run Tests
    
    func runAllTests() async {
        isLoading = true
        
        for i in 0..<testResults.count {
            currentTestIndex = i
            await runSingleTest(index: i)
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        calculateOverallSuccess()
        isLoading = false
    }
    
    private func runSingleTest(index: Int) async {
        let fileName = testResults[index].fileName
        
        guard let pdfURL = Bundle.main.url(forResource: fileName, withExtension: "pdf") else {
            print("⚠️ PDF bulunamadı: \(fileName).pdf")
            testResults[index].isComplete = true
            return
        }
        
        do {
            let provider = PDFInputProvider(url: pdfURL)
            let blocks = try await provider.process()
            let parsed = spatialParser.parse(blocks)
            
            testResults[index].extracted = DemoTestResult.ExtractedData(
                ettn: parsed.ettn,
                invoiceNumber: parsed.invoiceNumber,
                supplierName: parsed.supplier,
                totalAmount: parsed.totalAmount,
                date: parsed.date.map { formatDate($0) }
            )
            testResults[index].isComplete = true
            
        } catch {
            print("❌ Test hatası: \(error.localizedDescription)")
            testResults[index].isComplete = true
        }
    }
    
    private func calculateOverallSuccess() {
        let totalMatches = testResults.reduce(0) { $0 + $1.matchCount }
        let totalFields = testResults.count * 5
        overallSuccessRate = Double(totalMatches) / Double(totalFields)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

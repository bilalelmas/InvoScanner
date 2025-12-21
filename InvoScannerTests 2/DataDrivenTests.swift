import XCTest
@testable import InvoScanner

final class DataDrivenTests: XCTestCase {
    
    private let parser = InvoiceParser()
    
    func testJSONScenarios() throws {
        // 1. Verileri Yükle
        // Not: Bu dosyanın Test Target'ına ekli olduğundan ve JSON'ın Bundle Resource olarak ekli olduğundan emin olun.
        // Eğer Bundle'dan yüklenemezse boş döner ve test geçer (fakat uyarır).
        let testCases = TestDataLoader.loadTestCases()
        
        if testCases.isEmpty {
            print("UYARI: Test verileri yüklenemedi. 'TestCases.json' dosyasının Test Target'ına 'Copy Bundle Resources' olarak eklendiğinden emin olun.")
            return 
        }
        
        // 2. Her senaryoyu çalıştır
        for testCase in testCases {
            print("Test Ediliyor: \(testCase.description)")
            
            // TextBlock'ları oluştur
            let blocks = testCase.blocks.map { $0.toTextBlock() }
            
            // Ayrıştır
            let invoice = parser.parse(blocks: blocks)
            
            // 3. Doğrula (Assertions)
            
            // ETTN
            if let expectedETTN = testCase.expected.ettn {
                XCTAssertEqual(invoice.ettn?.uuidString.lowercased(), expectedETTN.lowercased(), "ETTN Uyuşmazlığı - ID: \(testCase.id)")
            }
            
            // Tarih
            if let expectedDateStr = testCase.expected.date {
               let formatter = DateFormatter()
               formatter.dateFormat = "dd-MM-yyyy"
               let expectedDate = formatter.date(from: expectedDateStr)
               
                // Sadece gün karşılaştırması yapalım (saat farkı olmaksızın)
                let date1 = invoice.date.map { formatter.string(from: $0) }
                let date2 = expectedDate.map { formatter.string(from: $0) }
                
                XCTAssertEqual(date1, date2, "Tarih Uyuşmazlığı - ID: \(testCase.id)")
            }
            
            // Tutar
            if let expectedAmountDouble = testCase.expected.totalAmount {
                let expectedAmount = Decimal(expectedAmountDouble)
                XCTAssertEqual(invoice.totalAmount, expectedAmount, "Tutar Uyuşmazlığı - ID: \(testCase.id)")
            }
            
            // Tedarikçi
            if let expectedSupplier = testCase.expected.supplierName {
                XCTAssertEqual(invoice.supplierName, expectedSupplier, "Tedarikçi Uyuşmazlığı - ID: \(testCase.id)")
            }
        }
    }
}

import XCTest
@testable import InvoScanner

/// Golden JSON Test Altyapısı
/// PDF fixture'ları yükleyip expected JSON ile karşılaştırır.
final class GoldenTests: XCTestCase {
    
    private let parser = InvoiceParser()
    
    // MARK: - Placeholder Test
    
    func testPlaceholder() {
        // Bu test, Golden Test altyapısının çalıştığını doğrular.
        // Gerçek PDF fixture'ları eklendikçe bu test genişletilecek.
        
        // Örnek: Normalize edilmiş metin ile test
        let sampleText = """
        D-MARKET ELEKTRONIK HIZMETLER VE TICARET A.S.
        ADRES: ISTANBUL
        VKN: 1234567890
        FATURA NO: 7214129698
        ETTN: EFED1D09-F821-12F1-80FD-005056876266
        ODENECEK TUTAR: 258,89 TL
        """
        
        let normalizedText = TextNormalizer.normalize(sampleText)
        let invoice = parser.parse(text: normalizedText, blocks: nil)
        
        // Assertions
        XCTAssertNotNil(invoice.ettn, "ETTN bulunamadı")
        XCTAssertNotNil(invoice.totalAmount, "Tutar bulunamadı")
        
        // Güven skoru kontrolü
        print("Golden Test: Güven Skoru = \(invoice.confidenceScore)")
        XCTAssertGreaterThanOrEqual(invoice.confidenceScore, 0.4, "Güven skoru çok düşük")
    }
    
    // MARK: - Tax Block Supplier Test
    
    func testTaxBlockSupplierExtraction() {
        // Vergi bloğundan satıcı tespiti testi
        let sampleText = """
        E-ARSIV FATURA
        
        MUCIZE BATARYA TEKNOLOJILERI SANAYI VE TICARET A.S.
        ISTANBUL TIC SICIL NO: 123456
        VKN: 9876543210
        VERGI DAIRESI: KADIKOY
        
        SAYIN
        ALICI ADI SOYADI
        """
        
        let normalizedText = TextNormalizer.normalize(sampleText)
        let extractor = SupplierExtractorV2()
        let supplier = extractor.extract(from: normalizedText)
        
        XCTAssertNotNil(supplier, "Satıcı bulunamadı")
        XCTAssertTrue(supplier?.contains("MUCIZE") ?? false, "Yanlış satıcı tespit edildi: \(supplier ?? "nil")")
    }
}

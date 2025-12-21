import XCTest
@testable import InvoScanner

final class StrategyTests: XCTestCase {

    // Blok oluşturmak için yardımcı fonksiyon
    func createBlock(_ text: String, y: Double) -> TextBlock {
        return TextBlock(text: text, frame: CGRect(x: 0, y: y, width: 1.0, height: 0.05))
    }

    func testETTNStrategy() {
        let strategy = ETTNStrategy()
        
        // Durum 1: Standart satır
        let blocks1 = [createBlock("ETTN: 123e4567-e89b-12d3-a456-426614174000", y: 0.1)]
        XCTAssertEqual(strategy.extract(from: blocks1)?.uuidString.lowercased(), "123e4567-e89b-12d3-a456-426614174000")
        
        // Durum 2: Bölünmüş satır (Hepsiburada tarzı)
        let blocks2 = [
            createBlock("ETTN", y: 0.1),
            createBlock("123e4567-e89b-12d3-a456-426614174000", y: 0.12)
        ]
        XCTAssertEqual(strategy.extract(from: blocks2)?.uuidString.lowercased(), "123e4567-e89b-12d3-a456-426614174000")
    }
    
    func testDateStrategy() {
        let strategy = DateStrategy()
        
        // Durum 1: Etiket ve Tarih
        let blocks1 = [
            createBlock("Düzenleme Tarihi: 28-12-2023", y: 0.1)
        ]
        let date = strategy.extract(from: blocks1)
        XCTAssertNotNil(date)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        XCTAssertEqual(formatter.string(from: date!), "28-12-2023")
    }
    
    func testAmountStrategy() {
        let strategy = AmountStrategy()
        
        // Durum 1: Alt %30 kuralı
        let blocks = [
            createBlock("Ara Toplam: 100,00", y: 0.8),
            createBlock("Genel Toplam: 1.250,50", y: 0.9), // Bunu seçmeli (maks & anahtar kelime)
            createBlock("Header Value: 5000,00", y: 0.1) // Bunu görmezden gelmeli (sayfanın üstü)
        ]
        
        XCTAssertEqual(strategy.extract(from: blocks), 1250.50)
    }
    
    func testSupplierStrategy() {
        let strategy = SupplierStrategy()
        
        // Durum 1: Üst %20 kuralı
        let blocks = [
            createBlock("YENİ MAĞAZACILIK A.Ş.", y: 0.05), // Bunu seçmeli
            createBlock("Müşteri Hizmetleri", y: 0.1),
            createBlock("Alt Firma LTD. ŞTİ.", y: 0.8) // Bunu görmezden gelmeli (alt kısım)
        ]
        
        XCTAssertEqual(strategy.extract(from: blocks), "YENİ MAĞAZACILIK A.Ş.")
    }
}

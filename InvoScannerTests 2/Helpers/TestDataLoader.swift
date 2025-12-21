import Foundation
import CoreGraphics
@testable import InvoScanner

// Test verilerini haritalamak için Codable yapılar
struct TestCase: Codable {
    let id: String
    let description: String
    let blocks: [TestBlock]
    let expected: TestExpected
}

struct TestBlock: Codable {
    let text: String
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    
    func toTextBlock() -> TextBlock {
        return TextBlock(text: text, frame: CGRect(x: x, y: y, width: w, height: h))
    }
}

struct TestExpected: Codable {
    let ettn: String?
    let date: String?
    let totalAmount: Double?
    let supplierName: String?
}

class TestDataLoader {
    
    static func loadTestCases() -> [TestCase] {
        guard let url = Bundle(for: TestDataLoader.self).url(forResource: "TestCases", withExtension: "json") else {
            // Bundle bullunamadıysa (CLI testlerde bazen olur), dosya yolundan dene (Test amaçlı hardcoded path fallback)
            // Not: Gerçek projede Bundle kaynaklarına "Copy Files" fazı ile eklenmelidir.
            // Şimdilik bundle erişimi varsayıyoruz, Resource handling XCTest içinde bazen tricky olabilir.
            // Alternatif: Doğrudan relative path dene.
            print("HATA: TestCases.json Bundle içinde bulunamadı.")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let cases = try JSONDecoder().decode([TestCase].self, from: data)
            return cases
        } catch {
            print("HATA: JSON Decod hatası: \(error)")
            return []
        }
    }
}

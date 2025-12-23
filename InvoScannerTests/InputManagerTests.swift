import XCTest
@testable import InvoScanner

/// InputManager ve Input Provider'lar için unit testler
/// - Test Kapsamı: PDFInputProvider, ImageInputProvider, GalleryInputProvider
final class InputManagerTests: XCTestCase {
    
    // MARK: - Mock Helpers
    
    /// Test için basit bir beyaz görsel oluşturur
    private func createTestImage(width: Int = 100, height: Int = 100) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // Test metni ekle
            let text = "TEST FATURA 123"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            text.draw(at: CGPoint(x: 10, y: 10), withAttributes: attributes)
        }
    }
    
    // MARK: - InputError Tests
    
    func testInputErrorDescriptions() {
        XCTAssertNotNil(InputError.invalidPDF.errorDescription)
        XCTAssertNotNil(InputError.emptyImage.errorDescription)
        XCTAssertNotNil(InputError.ocrFailed.errorDescription)
        XCTAssertNotNil(InputError.processingFailed("test").errorDescription)
        
        XCTAssertTrue(InputError.invalidPDF.errorDescription!.contains("PDF"))
        XCTAssertTrue(InputError.emptyImage.errorDescription!.contains("Görsel"))
    }
    
    // MARK: - ImageInputProvider Tests
    
    func testImageInputProviderWithValidImage() async throws {
        let testImage = createTestImage()
        let provider = ImageInputProvider(image: testImage)
        
        // OCR sonucu boş olabilir (test görseli basit)
        // Ama hata fırlatmamalı
        let blocks = try await provider.process()
        XCTAssertNotNil(blocks)
        // Not: Basit beyaz görsel üzerinde text olmayabilir, bu yüzden count kontrolü yapmıyoruz
    }
    
    func testImageInputProviderWithEmptyImage() async {
        // Geçersiz görsel (cgImage nil)
        let emptyImage = UIImage()
        let provider = ImageInputProvider(image: emptyImage)
        
        do {
            _ = try await provider.process()
            XCTFail("Hata fırlatılmalıydı")
        } catch let error as InputError {
            XCTAssertEqual(error, InputError.emptyImage)
        } catch {
            XCTFail("Yanlış hata tipi: \(error)")
        }
    }
    
    // MARK: - PDFInputProvider Tests
    
    func testPDFInputProviderWithInvalidURL() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        let provider = PDFInputProvider(url: invalidURL)
        
        do {
            _ = try await provider.process()
            XCTFail("Hata fırlatılmalıydı")
        } catch let error as InputError {
            XCTAssertEqual(error, InputError.invalidPDF)
        } catch {
            XCTFail("Yanlış hata tipi: \(error)")
        }
    }
    
    // MARK: - InputManager Tests
    
    func testInputManagerSingleton() {
        let manager1 = InputManager.shared
        let manager2 = InputManager.shared
        XCTAssertTrue(manager1 === manager2, "Singleton olmalı")
    }
    
    func testInputManagerProcessImage() async throws {
        let testImage = createTestImage()
        let blocks = try await InputManager.shared.process(source: .image(testImage))
        XCTAssertNotNil(blocks)
    }
    
    func testInputManagerProcessCameraThrowsError() async {
        do {
            _ = try await InputManager.shared.process(source: .camera)
            XCTFail("Camera case hata fırlatmalı")
        } catch {
            // Beklenen davranış
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - InputSource Tests
    
    func testInputSourceEnumCases() {
        let pdfSource = InputSource.pdf(URL(fileURLWithPath: "/test.pdf"))
        let imageSource = InputSource.image(UIImage())
        let cameraSource = InputSource.camera
        
        // Enum case'leri doğru oluşturulmalı
        if case .pdf(let url) = pdfSource {
            XCTAssertEqual(url.lastPathComponent, "test.pdf")
        } else {
            XCTFail("PDF case eşleşmedi")
        }
        
        if case .image = imageSource {
            XCTAssertTrue(true)
        } else {
            XCTFail("Image case eşleşmedi")
        }
        
        if case .camera = cameraSource {
            XCTAssertTrue(true)
        } else {
            XCTFail("Camera case eşleşmedi")
        }
    }
}

// MARK: - InputError Equatable Extension (Test için)

extension InputError: Equatable {
    public static func == (lhs: InputError, rhs: InputError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidPDF, .invalidPDF): return true
        case (.emptyImage, .emptyImage): return true
        case (.ocrFailed, .ocrFailed): return true
        case (.processingFailed(let l), .processingFailed(let r)): return l == r
        default: return false
        }
    }
}

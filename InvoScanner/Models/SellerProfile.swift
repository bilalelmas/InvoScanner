import Foundation

/// Bilinen satıcılar için profil tanımları
/// Platform satışlarında sabit satıcı adı döndürmek için kullanılır.
struct SellerProfile {
    let name: String
    let detectionKeywords: [String]
    let forceSupplierName: String?
    
    /// Metin bu profile uyuyor mu?
    func matches(text: String) -> Bool {
        for keyword in detectionKeywords {
            if text.contains(keyword) {
                return true
            }
        }
        return false
    }
}

/// Bilinen satıcı profilleri deposu
struct SellerProfileRegistry {
    
    static let profiles: [SellerProfile] = [
        // Hepsiburada Platform Satışı
        SellerProfile(
            name: "D-MARKET",
            detectionKeywords: ["D-MARKET", "D MARKET ELEKTRONIK"],
            forceSupplierName: "D-MARKET ELEKTRONİK HİZMETLER VE TİC. A.Ş."
        ),
        
        // Trendyol Platform Satışı
        SellerProfile(
            name: "DSM GRUP",
            detectionKeywords: ["DSM GRUP", "DSMGRUP"],
            forceSupplierName: "DSM GRUP DANIŞMANLIK İLETİŞİM VE SATIŞ TİC.A.Ş."
        )
    ]
    
    /// Metne uyan profili bul
    static func findProfile(for text: String) -> SellerProfile? {
        return profiles.first { $0.matches(text: text) }
    }
}

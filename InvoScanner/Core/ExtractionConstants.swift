import Foundation

/// Çıkarım motoru için merkezi sabitler (Centralized Constants)
/// Tüm desenler (patterns) ve anahtar kelimeler burada toplanmıştır.
struct ExtractionConstants {
    
    // MARK: - Adres ve İletişim
    
    /// Adres verisi işaretçileri (Yapısal)
    static let addressMarkers = [
        "MAH", "MAH.", "MAHALLESI", "MAHALLESİ", "MH.",
        "CAD", "CAD.", "CADDESI", "CADDESİ", "CADDDE",
        "SOK", "SOK.", "SOKAK", "SOKAGI", "SK.", "SK",
        "NO:", "NO :", "NO.",
        "APT", "APARTMANI", "DAIRE", "DAİRE", "KAT:", "KAT",
        "BLOK", "BINA", "KONUT", "PLAZA", "IS MERKEZI",
        "MEYDAN", "BULVAR", "KUME EVLER"
    ]
    
    static let contactMarkers = [
        "TEL:", "TEL :", "TELEFON:", "TLF",
        "FAX:", "FAX :", "FAKS:",
        "E-POSTA:", "E-POSTA", "EMAIL:", "MAIL:",
        "WEB:", "WEB SITESI:", "WWW.", "HTTP",
        "GSM:", "CEP:"
    ]
    
    // MARK: - Kurumsal ve Vergi
    
    /// Kurumsal şirket sonekleri
    static let corporateSuffixes = [
        "A.S.", "A.S", "A.Ş.", "AŞ", "AS",
        "LTD.", "LTD", "LIMITED", "LİMİTED",
        "STI.", "STI", "ŞTİ.", "ŞTİ",
        "TIC.", "TİC.",
        "SAN.", "SANAYI", "SANAYİ",
        "ANONIM", "ANONİM",
        "SIRKETI", "ŞİRKETİ",
        "MAGAZACILIK", "MAĞAZACILIK",
        "HIZMETLERI", "HİZMETLERİ"
    ]
    
    /// Vergi ve yasal kimlik işaretçileri
    static let taxIndicators = [
        "VKN", "VKN:", "VERGI NO", "VERGİ NO",
        "TCKN", "TCKN:", "TC NO", "TC KIMLIK",
        "VERGI DAIRESI", "VERGİ DAİRESİ", "V.D.",
        "MERSIS", "MERSİS", "TICARET SICIL", "SICIL NO"
    ]
    
    // MARK: - Filtreleme (Stop/Exclude)
    
    /// Satıcı tespitinde "Dur" kelimeleri (Alıcı veya Belge başlangıcı)
    static let stopPatterns = [
        "SAYIN", "SAYIN:",
        "ALICI", "ALICI:",
        "MUSTERI", "MÜŞTERİ",
        "TESLIMAT ADRESI", "TESLİMAT",
        "FATURA", "E-ARSIV", "EARSIV", "E-FATURA"
    ]
    
    /// Satıcı olamayacak kargo ve pazar yeri firmaları
    static let excludedCompanies = [
        // Kargo Firmaları
        "PTT", "POSTA VE TELGRAF",
        "ARAS KARGO", "YURTICI KARGO", "YURTİÇİ KARGO",
        "MNG KARGO", "SURAT KARGO", "SÜRAT KARGO",
        "UPS", "DHL", "FEDEX", "TNT",
        "HEPSIJET", "HEPSİJET", "D FAST",
        "SENDEO", "KARGOIST", "KARGOİST",
        "KOLAY GELSIN", "KOLAY GELSİN",
        "TRENDYOL EXPRESS", "TEX",
        
        // Pazar Yerleri (Genellikle aracıdır)
        "TRENDYOL", "DSM GRUP",
        "HEPSIBURADA", "HEPSİBURADA", "D-MARKET",
        "N11", "DOGUS PLANET",
        "CICEK SEPETI", "ÇİÇEK SEPETİ",
        "AMAZON",
        "GITTIGIDIYOR",
        "YEMEK SEPETI"
    ]
    
    /// Kargo ile ilgili kelimeler (Satır eleme için)
    static let cargoKeywords = [
        "GONDERI", "GÖNDERİ",
        "TASIYAN", "TAŞIYAN",
        "KARGO", "LADING", "SHIPMENT",
        "DESI", "AGIRLIK", "PAKET"
    ]
    
    // MARK: - Footer & Belge Tipi
    
    static let footerKeywords = [
        "GIB", "GİB",
        "GELIR IDARESI", "GELİR İDARESİ",
        "MERSIS", "KEP ADRESI",
        "ZAMAN DAMGASI", "E-IMZA", "E-İMZA"
    ]
    
    static let documentTypeKeywords = [
        "ARSIV FATURA", "ARŞİV FATURA",
        "E-ARSIV", "E-ARŞİV",
        "FATURA", "FATURA NO"
    ]
    
    // MARK: - V5.3 Semantik Etiketler
    
    /// Satıcı bölümü işaretçileri (Moonlife, Vestel varyasyonları dahil)
    static let sellerLabels = [
        "SATICI", "SATICI:", "SATICI (MERKEZ):", "SATICI(MERKEZ):",
        "İŞLETME MERKEZİ", "ISLETME MERKEZI",
        "SATICININ", "SATICININ:"
    ]
    
    /// Alıcı bölümü işaretçileri (Hepsiburada varyasyonu dahil)
    static let buyerLabels = [
        "ALICI", "ALICI:", "ALICI (ŞUBE):", "ALICI(ŞUBE):",
        "MÜŞTERİ V.D. VKN/TCKN", "MUSTERI V.D. VKN/TCKN",
        "MÜŞTERİ VD VKN", "MUSTERI VD VKN"
    ]
    
    /// Fatura meta veri etiketleri
    static let invoiceMetaLabels = [
        "FATURA NO", "FATURA NO:", "FATURA NUMARASI", "FATURA NUMARASI:",
        "DÜZENLENME TARİHİ", "DUZENLEME TARIHI", "DÜZENLEME TARİHİ",
        "DÜZENLENME SAATİ", "DUZENLEME SAATI", "DÜZENLEME SAATİ"
    ]
    
    /// V5.3: Marka sloganları ve gürültü ifadeleri (satıcı adı temizliği için)
    static let sloganNoise = [
        // Marka sloganları
        "YEŞİLİ BİRLİKTE YAŞATALIM", "YESILI BIRLIKTE YASATALIM",
        "GÜVENİLİR ALIŞVERİŞ", "GUVENILIR ALISVERIS",
        "GÜVENİL ALIŞVERİŞ", "GUVENIL ALISVERIS",
        "MOBİLYA AŞKI", "MOBILYA ASKI",
        // Sayfa numaraları
        "SAYFA 1", "SAYFA 1/1", "PAGE 1", "PAGE 1/1",
        "SAYFA:", "PAGE:"
    ]
}

import Foundation

/// Çıkarım motoru için merkezi sabitler
struct ExtractionConstants {
    
    // MARK: - Adres ve İletişim
    
    /// Adresi belirten anahtar kelimeler
    static let addressMarkers = [
        "MAH", "MAH.", "MAHALLESI", "MAHALLESİ", "MH.",
        "CAD", "CAD.", "CADDESI", "CADDESİ", "CADDDE",
        "SOK", "SOK.", "SOKAK", "SOKAGI", "SK.", "SK",
        "NO:", "NO :", "NO.",
        "APT", "APARTMANI", "DAIRE", "DAİRE", "KAT:", "KAT",
        "BLOK", "BINA", "KONUT", "PLAZA", "IS MERKEZI",
        "MEYDAN", "BULVAR", "KUME EVLER"
    ]
    
    /// İletişim bilgilerini belirten anahtar kelimeler
    static let contactMarkers = [
        "TEL:", "TEL :", "TELEFON:", "TLF",
        "FAX:", "FAX :", "FAKS:",
        "E-POSTA:", "E-POSTA", "EMAIL:", "MAIL:",
        "WEB:", "WEB SITESI:", "WWW.", "HTTP",
        "GSM:", "CEP:"
    ]
    
    // MARK: - Kurumsal ve Vergi
    
    /// Şirket unvanı sonekleri
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
    
    /// Şirket türü sonekleri (Sıralı liste)
    static let legalSuffixesOrdered = [
        "SANAYİ VE TİCARET LİMİTED ŞİRKETİ",
        "SANAYI VE TICARET LIMITED SIRKETI",
        "SANAYİ VE TİCARET ANONİM ŞİRKETİ",
        "SANAYI VE TICARET ANONIM SIRKETI",
        "TİCARET VE SANAYİ LİMİTED ŞİRKETİ",
        "TICARET VE SANAYI LIMITED SIRKETI",
        "DIŞ TİCARET LİMİTED ŞİRKETİ",
        "DIS TICARET LIMITED SIRKETI",
        "PAZARLAMA LİMİTED ŞİRKETİ",
        "PAZARLAMA LIMITED SIRKETI",
        "HİZMETLERİ LİMİTED ŞİRKETİ",
        "HIZMETLERI LIMITED SIRKETI",
        "MAĞAZACILIK LİMİTED ŞİRKETİ",
        "MAGAZACILIK LIMITED SIRKETI",
        "SAN. VE TİC. LTD. ŞTİ.",
        "SAN. VE TIC. LTD. STI.",
        "SANAYİ VE TİCARET A.Ş.",
        "SANAYI VE TICARET A.S.",
        "SAN. VE TİC. A.Ş.",
        "SAN. VE TIC. A.S.",
        "LİMİTED ŞİRKETİ",
        "LIMITED SIRKETI",
        "ANONİM ŞİRKETİ",
        "ANONIM SIRKETI",
        "TİCARET A.Ş.",
        "TICARET A.S.",
        "TİC. A.Ş.",
        "TIC. A.S.",
        "LTD. ŞTİ.",
        "LTD. STI.",
        "LTD.ŞTİ.",
        "LTD.STI.",
        "LTD ŞTİ",
        "LTD STI",
        "A.Ş.",
        "A.S.",
        "AŞ.",
        "AS.",
        "A.Ş",
        "A.S",
        "LTD.",
        "LTD",
        "ŞTİ.",
        "STI."
    ]
    
    /// Vergi ve kimlik işaretçileri
    static let taxIndicators = [
        "VKN", "VKN:", "VERGI NO", "VERGİ NO",
        "TCKN", "TCKN:", "TC NO", "TC KIMLIK",
        "VERGI DAIRESI", "VERGİ DAİRESİ", "V.D.",
        "MERSIS", "MERSİS", "TICARET SICIL", "SICIL NO"
    ]
    
    // MARK: - Filtreleme
    
    /// Durdurma kelimeleri (Alıcı veya Belge başlangıcı)
    static let stopPatterns = [
        "SAYIN", "SAYIN:",
        "ALICI", "ALICI:",
        "MUSTERI", "MÜŞTERİ",
        "TESLIMAT ADRESI", "TESLİMAT",
        "FATURA", "E-ARSIV", "EARSIV", "E-FATURA"
    ]
    
    /// Hariç tutulacak kargo ve pazar yeri firmaları
    static let excludedCompanies = [
        "PTT", "POSTA VE TELGRAF",
        "ARAS KARGO", "YURTICI KARGO", "YURTİÇİ KARGO",
        "MNG KARGO", "SURAT KARGO", "SÜRAT KARGO",
        "UPS", "DHL", "FEDEX", "TNT",
        "HEPSIJET", "HEPSİJET", "D FAST",
        "SENDEO", "KARGOIST", "KARGOİST",
        "KOLAY GELSIN", "KOLAY GELSİN",
        "TRENDYOL EXPRESS", "TEX",
        "TRENDYOL", "DSM GRUP",
        "HEPSIBURADA", "HEPSİBURADA", "D-MARKET",
        "N11", "DOGUS PLANET",
        "CICEK SEPETI", "ÇİÇEK SEPETİ",
        "AMAZON",
        "GITTIGIDIYOR",
        "YEMEK SEPETI"
    ]
    
    /// Kargo ilgili anahtar kelimeler
    static let cargoKeywords = [
        "GONDERI", "GÖNDERİ",
        "TASIYAN", "TAŞIYAN",
        "KARGO", "LADING", "SHIPMENT",
        "DESI", "AGIRLIK", "PAKET"
    ]
    
    // MARK: - Alt Bilgi ve Belge Tipi
    
    /// Belge sonu anahtar kelimeleri
    static let footerKeywords = [
        "GIB", "GİB",
        "GELIR IDARESI", "GELİR İDARESİ",
        "MERSIS", "KEP ADRESI",
        "ZAMAN DAMGASI", "E-IMZA", "E-İMZA"
    ]
    
    /// Belge tipini belirten anahtar kelimeler
    static let documentTypeKeywords = [
        "ARSIV FATURA", "ARŞİV FATURA",
        "E-ARSIV", "E-ARŞİV",
        "FATURA", "FATURA NO"
    ]
    
    // MARK: - Semantik Etiketler
    
    /// Satıcı etiketi varyasyonları
    static let sellerLabels = [
        "SATICI", "SATICI:", "SATICI (MERKEZ):", "SATICI(MERKEZ):",
        "İŞLETME MERKEZİ", "ISLETME MERKEZI",
        "SATICININ", "SATICININ:"
    ]
    
    /// Alıcı etiketi varyasyonları
    static let buyerLabels = [
        "ALICI", "ALICI:", "ALICI (ŞUBE):", "ALICI(ŞUBE):",
        "MÜŞTERİ V.D. VKN/TCKN", "MUSTERI V.D. VKN/TCKN",
        "MÜŞTERİ VD VKN", "MUSTERI VD VKN"
    ]
    
    /// Fatura detay etiketleri
    static let invoiceMetaLabels = [
        "FATURA NO", "FATURA NO:", "FATURA NUMARASI", "FATURA NUMARASI:",
        "BELGE NO", "BELGE NO:",
        "DÜZENLENME TARİHİ", "DUZENLEME TARIHI", "DÜZENLEME TARİHİ",
        "DÜZENLENME SAATİ", "DUZENLEME SAATI", "DÜZENLEME SAATİ"
    ]
    
    /// Tarih bilgisini belirten etiketler
    static let dateLabels = [
        "FATURA TARİHİ", "FATURA TARIHI",
        "DÜZENLENME TARİHİ", "DUZENLEME TARIHI", "DÜZENLEME TARİHİ",
        "TARİH", "TARIH",
        "DATE"
    ]
    
    /// Temizlenecek slogan ve gürültü metinleri
    static let sloganNoise = [
        "YEŞİLİ BİRLİKTE YAŞATALIM", "YESILI BIRLIKTE YASATALIM",
        "GÜVENİLİR ALIŞVERİŞ", "GUVENILIR ALISVERIS",
        "GÜVENİL ALIŞVERİŞ", "GUVENIL ALISVERIS",
        "MOBİLYA AŞKI", "MOBILYA ASKI",
        "SAYFA 1", "SAYFA 1/1", "PAGE 1", "PAGE 1/1",
        "SAYFA:", "PAGE:"
    ]
    
    // MARK: - Uzamsal Eşikler
    
    /// Tepe bölgesi gürültü eşiği
    static let topMarginNoiseThreshold: CGFloat = 0.10
}

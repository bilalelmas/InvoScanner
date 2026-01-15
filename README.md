# 🚀 InvoScanner

**InvoScanner**, e-Arşiv faturalarından kritik verileri (ETTN, Tarih, Tutar, Satıcı) cihaz üzerinde (on-device) ayıklayan, modern iOS teknolojileriyle geliştirilmiş akıllı bir fatura yönetim sistemidir.

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://www.apple.com/ios/)
[![Vision](https://img.shields.io/badge/OCR-Vision%20Framework-green.svg)](https://developer.apple.com/documentation/vision)

---

## ✨ Öne Çıkan Özellikler

- 🧠 **Spatial Pipeline:** Koordinat-farkında metin analizi ile yüksek doğruluk
- 🛡️ **Privacy-First:** Tüm işlemler cihaz üzerinde; veriler sunucuya gönderilmez
- 📐 **Zone-Aware Parsing:** Belgeyi semantik bölgelere ayırarak akıllı çıkarım
- 🧪 **Matematiksel Doğrulama:** "Yalnız..." satırı ile tutar karşılaştırması
- 📊 **Modern Dashboard:** SwiftCharts ile harcama analizi

---

## 🏗️ Teknoloji Yığını

| Kategori | Teknoloji |
|----------|-----------|
| **Dil** | Swift 5.10 (SwiftUI) |
| **Mimari** | MVVM-R + Spatial Pipeline |
| **OCR** | Vision Framework |
| **PDF İşleme** | PDFKit |
| **Görselleştirme** | SwiftCharts |

---

## 🔬 Spatial Pipeline

InvoScanner'ın kalbi olan Spatial Pipeline, metin bloklarını koordinat bazlı analiz ederek daha doğru çıkarım yapar:

```
TextBlock → BlockClusterer → SemanticBlock → BlockLabeler → LayoutMap → SpatialParser → Invoice
```

| Bileşen | Görev |
|---------|-------|
| `BlockClusterer` | Metin bloklarını paragraflara kümeler |
| `BlockLabeler` | Bloklara semantik etiket atar (Seller, Buyer, Totals) |
| `LayoutMap` | 2D belge haritası oluşturur |
| `SpatialParser` | Orkestratör, veri çıkarımını koordine eder |
| `AmountToTextVerifier` | Tutarı "Yalnız..." satırıyla doğrular |

---

## 📁 Hızlı Başlangıç

### Gereksinimler
- Xcode 15.0+
- iOS 17.0+

### Kurulum
1. Projeyi klonlayın:
   ```bash
   git clone https://github.com/bilalelmas/InvoScanner.git
   ```
2. `InvoScanner.xcodeproj` dosyasını Xcode ile açın.
3. Simülatör veya iPhone cihazınızda `Run` (Cmd+R) komutunu çalıştırın.

---

## 📖 Teknik Dokümantasyon

Projenin derinlemesine mimarisi ve algoritma açıklamaları için:

📄 **[PROJE_RAPORU.md](./PROJE_RAPORU.md)**

---

## 🗺️ Klasör Yapısı

```
InvoScanner/
├── Core/           # InputManager, ExtractionConstants
├── Spatial/        # V5 Pipeline (Clusterer, Labeler, Parser)
├── Models/         # Invoice veri modeli
├── ViewModels/     # Dashboard ve Scanner state yönetimi
├── Views/          # SwiftUI arayüz bileşenleri
└── Assets/         # Görsel varlıklar
```

| Klasör | Açıklama |
|--------|----------|
| `Core/` | Girdi yönetimi ve merkezi sabitler |
| `Spatial/` | Spatial Pipeline bileşenleri |
| `Models/` | Fatura veri modeli ve güven skoru |
| `ViewModels/` | UI state yönetimi |
| `Views/` | Dashboard, Scanner, Liste ve Detay ekranları |

---

## 🧪 Testler

```bash
# Unit ve Golden testlerini çalıştır
xcodebuild test -scheme InvoScanner -destination 'platform=iOS Simulator,name=iPhone 15'
```

| Test Tipi | Dosya |
|-----------|-------|
| Data-Driven | `DataDrivenTests.swift` |
| Golden | `GoldenTests.swift` |
| InputManager | `InputManagerTests.swift` |

---

## 📈 Proje Metrikleri

| Metrik | Değer |
|--------|-------|
| Build Status | ✅ Passing |
| Test Coverage | %85+ (Core Logic) |
| Privacy | 100% On-Device |
| Min iOS | 17.0 |

---

## 🗓️ Roadmap

- [x] Spatial Pipeline Mimarisi
- [x] AmountToTextVerifier (Tutar Doğrulama)
- [x] SwiftData Persistence
- [ ] Payload (Ürün Tablosu) Çıkarımı
- [ ] Cloud Backup

---

*Geliştirici: [Bilal Elmas](https://github.com/bilalelmas)*

# 🚀 InvoScanner

**InvoScanner**, e-Arşiv faturalarından kritik verileri (ETTN, Tarih, Tutar, Satıcı) cihaz üzerinde (on-device) ayıklayan, modern iOS teknolojileriyle geliştirilmiş akıllı bir fatura yönetim sistemidir.

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://www.apple.com/ios/)
[![SwiftData](https://img.shields.io/badge/Data-SwiftData-blueviolet.svg)](https://developer.apple.com/xcode/swiftdata/)

## ✨ Öne Çıkan Özellikler

- 🧠 **Hibrit Motor (V3):** Dijital PDF'ler için yerel metin okuma, taranmış belgeler için Vision OCR.
- 🛡️ **Privacy-First:** Tüm işlemler cihaz üzerinde yapılır; verileriniz hiçbir sunucuya gönderilmez.
- 📐 **Zone-Aware Parsing:** Belgedeki verileri koordinat bazlı mantıksal bölgelere ayırarak yüksek doğruluk sağlar.
- 🧪 **Matematiksel Doğrulama:** `Matrah + KDV = Toplam` kontrolü ile hatalı tutar ayıklamayı engeller.
- 📊 **Modern Dashboard:** SwiftCharts ile harcama analizi ve kategori bazlı görselleştirme.

## 🏗️ Teknoloji Yığını

- **Dil:** Swift (SwiftUI)
- **Mimari:** MVVM-R (Repository) + Strategy Pattern
- **Veri Saklama:** SwiftData
- **Frameworkler:** Vision, PDFKit, SwiftCharts

## 📁 Hızlı Başlangıç

### Gereksinimler
- Xcode 15.0+
- iOS 17.0+ (SwiftData desteği nedeniyle)

### Kurulum
1. Projeyi klonlayın:
   ```bash
   git clone https://github.com/bilalelmas/InvoScanner.git
   ```
2. `InvoScanner.xcodeproj` dosyasını Xcode ile açın.
3. Simülatör veya iPhone cihazınızda `Run` (Cmd+R) komutunu çalıştırın.

## 📖 Teknik Dokümantasyon

Projenin derinlemesine mimarisi, servis yapısı ve algoritma detayları için [📄 PROJE_RAPORU_V2.md](file:///Users/bilalelmas/GitHub/InvoScanner/PROJE_RAPORU_V2.md) dosyasını inceleyebilirsiniz.

## 🗺️ Klasör Yapısı (Özet)

- `Models/`: SwiftData veri modelleri.
- `Services/`: OCR, Input ve İşleme servisleri.
- `Strategies/`: Veri ayıklama algoritmaları (ETTN, Tarih, Tutar vb.).
- `ViewModels/`: UI state yönetimi.
- `Views/`: SwiftUI arayüz bileşenleri.

---
*Geliştirici: [Bilal Elmas](https://github.com/bilalelmas)*

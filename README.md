# InvoScanner (V0)

InvoScanner, e-Arşiv faturalarını tarayarak üzerindeki önemli verileri (ETTN, Tarih, Toplam Tutar, Tedarikçi) cihaz üzerinde hiçbir veriyi dışarıya göndermeden (Privacy-First) ayıklayan iOS tabanlı bir uygulamadır.

## 📋 Proje Özeti
- **Amaç:** Fatura takibini kolaylaştırmak için otomatik veri girişi sağlamak.
- **Teknoloji:** iOS 17+, SwiftUI, Vision Framework (OCR), MVVM Mimarisi.
- **Yaklaşım:** "Az ama Öz" (V0 MVP). Karmaşık bulut çözümleri yerine yerel Apple kütüphanelerini kullanır.
- **Durum:** V0 sürümü tamamlandı, V1 için mimari planlama yapıldı.

---

## 🏗 Klasör Yapısı
Proje, Sorumlulukların Ayrılığı (Separation of Concerns) ilkesine göre yapılandırılmıştır:

```
InvoScanner/
├── InvoScanner/
│   ├── InvoScannerApp.swift    # Giriş Noktası
│   ├── Models/
│   │   ├── Invoice.swift       # Fatura Veri Modeli
│   │   └── TextBlock.swift     # Normalize Edilmiş OCR Bloğu
│   ├── Services/
│   │   ├── OCRService.swift    # Vision/PDF -> Metin Dönüşümü
│   │   └── InvoiceParser.swift # Koordinatör (Stratejileri Yönetir)
│   ├── Strategies/
│   │   ├── Protocols/ExplanationStrategy.swift
│   │   └── Implementations/    # ETTN, Date, Amount, Supplier Logic
│   ├── ViewModels/
│   │   └── ScannerViewModel.swift # UI ve İş Mantığı Köprüsü
│   └── Views/
│       ├── ScannerView.swift   # Ana Ekran
│       └── ResultView.swift    # Sonuç Gösterimi
├── InvoScannerTests/
│   ├── StrategyTests.swift     # Birim Testler
│   ├── DataDrivenTests.swift   # JSON Tabanlı Senaryo Testleri
│   └── Resources/
│       └── TestCases.json      # Test Verileri
└── SampleInvoices/             # Test Amaçlı Örnek Faturalar
```

---

## ⚙️ Çalışma Mantığı (Workflow)

Sistem 4 ana aşamadan oluşur:

### 1. Girdi ve OCR (OCRService)
Kullanıcı bir **PDF** veya **Görüntü** seçer.
- **Görüntü ise:** Doğrudan Vision Framework ile tarama.
- **PDF ise:** İlk sayfa yüksek çözünürlüklü bir görüntüye ("render") dönüştürülür ve Vision'a verilir.
- **Çıktı:** `[TextBlock]` listesi (Metin içeriği + Normalize Edilmiş Çerçeve [0..1]).

### 2. Ayrıştırma (InvoiceParser & Strategies)
Ham metin blokları stratejilere dağıtılır. Her strateji spesifik bir veriyi arar:
- **ETTN:** Regex ile UUID formatını arar (+ Bölünmüş satır kontrolü).
- **Tarih:** "Tarih" anahtar kelimesi yakınındaki dd-MM-yyyy formatlarını tarar.
- **Tutar:** Belgenin **alt %30**'luk kısmına odaklanır, "Toplam" etiketlerini ve en büyük sayıyı arar.
- **Tedarikçi:** Belgenin **üst %20**'lik kısmına odaklanır, Şirket uzantılarını (A.Ş., LTD.) arar.

### 3. Sunum (MVVM)
`ScannerViewModel`, asenkron olarak OCR ve Ayrıştırma işini yönetir. Sonuç `Invoice` nesnesine dönüştürülerek UI'da gösterilir.

### 4. Test (Data-Driven)
OCR katmanından bağımsız olarak, sadece mantığı test etmek için JSON tabanlı bir test sistemi kurulmuştur.
- Ham verileri (`blocks`) JSON'dan alır.
- Parser'dan geçirir.
- Beklenen (`expected`) sonuçlarla kıyaslar.

---

## 🚀 Nasıl Çalıştırılır?

1. Projeyi Xcode ile açın.
2. Hedef (Target) olarak bir Simülatör seçin.
3. **Cmd+R** ile uygulamayı başlatın.
4. "Belge Yükle" diyerek `SampleInvoices` klasöründeki veya kendi faturanızı seçin.

---

## 🔮 Gelecek Planı (V1 Architecture)
V1 sürümü için daha gelişmiş bir **Hibrit Pipeline** tasarlanmıştır:
1. Önce **PDFKit** ile metin katmanını okuma (OCR'sız, %100 doğruluk).
2. Başarısız olursa **Vision OCR**'a düşme (Fallback).
3. **Strict Normalization:** Tüm metinleri standartlaştırma.
4. **Resover Pattern:** Vendor'a özel (Trendyol, Hepsiburada) ayrıştırıcı seçimi.

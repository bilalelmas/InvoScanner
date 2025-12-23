# 📄 PROJE RAPORU: InvoScanner (V1)

## 1. Proje Tanımı
InvoScanner, e-Arşiv faturalarından kritik bilgileri en yüksek doğrulukla ayıklamak amacıyla geliştirilmiş, **Hibrit Ayrıştırma Motoru (Hybrid Extraction Engine)** kullanan akıllı bir mobil uygulama altyapısıdır. 

Sistem, iki kademeli bir yaklaşım benimser:
1.  **Native PDF Parsing:** Dijital faturalar için %100 doğrulukta metin okuma.
2.  **Vision Framework (OCR):** Taranmış belgeler veya fotoğrafı çekilmiş faturalar için yedekleme mekanizması.

Bu hibrit yapı, veri gizliliğini ve hızı maksimize etmek adına tamamen cihaz üzerinde (on-device) çalışır.

## 2. Proje Hedefleri
Proje, kapsam karmaşasından kaçınarak "Az ama doğru" ilkesiyle şu 4 alanı hedefler:

*   **ETTN (UUID):** Faturanın 36 karakterlik benzersiz yasal kimliği.
*   **Fatura Toplam Tutarı:** Vergiler dahil, ödenecek nihai tutar.
*   **Fatura Tarihi:** Dokümanın yasal düzenlenme tarihi.
*   **Satıcı İsmi (Yasal Ünvan):** Hizmeti sağlayan kurumun resmi ticari adı.

## 3. Teknik Mimari ve Teknoloji Yığını
Sistem, modülerliği ve genişletilebilirliği sağlamak adına MVVM-R, SwiftData ve Strategy Pattern prensipleri üzerine inşa edilmiştir.

*   **Platform & Dil:** iOS (Swift, SwiftUI).
*   **Veri Kalıcılığı:** SwiftData (Modern, hafif ve performanslı veritabanı).
*   **Pipeline Mimarisi:**
    `Input -> Hardware/OCR -> Normalization -> Strategy Chain -> Verification -> Persistence`

### 3.1. Veri Çıkarım Katmanı
*   **PDFKit Layer:** PDF dokümanlarından yapısal metinleri (TextLayer) doğrudan okuyarak OCR hatalarını (örn. 0/O, 1/I karışıklığı) sıfıra indirir.
*   **Vision Framework:** Apple'ın on-device OCR teknolojisi, sadece native metin erişimi olmayan durumlarda devreye girer.
*   **Normalizasyon:** Tüm kaynaklar, kaynak bağımsız bir **TextBlock** yapısına dönüştürülür.

## 4. Gelişmiş Ayrıştırma Stratejileri (V2/V3)
Gerçek saha verileri (Flo, Hepsiburada, Trendyol vb.) ile eğitilen stratejiler, V3 seviyesine yükseltilmiştir:

### 4.1. Tedarikçi Ayrıştırma (Supplier Extraction V3)
En karmaşık analiz modülüdür. "SAYIN" gibi hitap kelimelerini temizler ve veritabanı destekli çalışır.
*   **Yaklaşım:** "Anchor-based" + "Database Lookup".
*   **Mekanizma:**
    1.  Bilinen tedarikçiler (Trendyol, Hepsiburada) için `SellerProfile` üzerinden hızlı eşleşme.
    2.  Vergi No (VKN/TCKN) ve Mersis No tespitiyle satıcı bloğunun kesinleşmesi.
    3.  Gürültü kelimelerin (A.Ş., LTD. ŞTİ. vb.) varyasyonlarının yönetimi.

### 4.2. Toplam Tutar Tespiti (V3 - Math Verification)
Sadece metin okumaz, matematiksel doğrulama yapar.
*   **3 Aşamalı Kontrol:**
    1.  **Footer Priority:** Sayfanın en altındaki "Ödenecek Tutar" etiketli alana öncelik verilir.
    2.  **Largest Number:** İlgili bölgedeki en büyük sayısal değer adaydır.
    3.  **Math Check:** `| (Matrah + KDV) - Toplam | < 0.05` formülüyle tutarlılık doğrulanır. Hatalı okumaları engeller.

### 4.3. Tarih Normalizasyonu (Date V2)
Farklı formatları (dd-MM-yyyy, dd.MM.yyyy, yyyy-MM-dd) tek bir `Date` objesine dönüştürür.
*   **Kural:** "Düzenleme Tarihi" etiketine en yakın tarih seçilir; saat verisi temizlenir. Geçersiz tarih formatlarında `nil` dönerek hatalı veri girişini engeller.

### 4.4. ETTN Yakalama (Split-Line Handling)
E-Arşiv faturalarında sık görülen satır kayması (Line-Wrap) durumlarını yönetir.
*   **Kural:** "ETTN" anahtar kelimesinden sonra gelen blok 36 karakter değilse, sonraki satırla birleştirilip Regex (UUID) kontrolü yapılır.

## 5. Proje Klasör Yapısı
Proje, temiz mimari (Clean Architecture) prensiplerine göre organize edilmiştir:

*   **Strategies/Protocols:** Strateji arayüzleri.
*   **Strategies/Implementations:** Somut algoritmalar (DateStrategy, AmountStrategy vb.).
*   **Strategies/Specific:** Firmaya özel (Hardcoded) kurallar.
*   **Models:** SwiftData modelleri (`Invoice`, `SellerProfile`) ve DTO'lar (`TextBlock`).

### Metodoloji
Geliştirme sürecinde "Agentic Workflows" (.agent/workflows) aktif olarak kullanılmaktadır:
*   `ArchitectMode`: Mimari planlama.
*   `DebugMaster`: Hata ayıklama.
*   `RefactorSafe`: Güvenli kod iyileştirme.

## Sonuç
InvoScanner (V1), sadece bir OCR aracı değil; verinin bağlamını (context) anlayan, kendini doğrulayan (self-validating) ve hibrit çalışan akıllı bir ayrıştırma motorudur.

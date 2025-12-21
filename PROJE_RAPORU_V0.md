# 📄 PROJE RAPORU: InvoScanner (V0)

## 1. Proje Tanımı
InvoScanner, e-Arşiv faturalarından kritik bilgileri yüksek doğrulukla ayıklamak amacıyla geliştirilmiş, hafif (lightweight) ve kural tabanlı bir mobil uygulama altyapısıdır. Sistem; dijital PDF’ler, taranmış belgeler ve kamera görüntüleri gibi farklı girdi türlerini destekler. Tüm kaynaklar tek bir normalize veri yapısı (TextBlock) altında birleştirilir ve veri madenciliği işlemleri gizlilik ile hızı optimize etmek adına tamamen cihaz üzerinde (on-device) gerçekleştirilir.

## 2. Proje Hedefleri
Proje, kapsam karmaşasından kaçınarak "Az ama doğru" ilkesiyle şu 4 alanı hedeflemiştir:

*   **ETTN (UUID):** Faturanın 36 karakterlik benzersiz yasal kimliği.
*   **Fatura Toplam Tutarı:** Vergiler dahil, ödenecek nihai tutar.
*   **Fatura Tarihi:** Dokümanın yasal düzenlenme tarihi.
*   **Satıcı İsmi (Yasal Ünvan):** Hizmeti sağlayan kurumun resmi ticari adı.

## 3. Teknik Mimari ve Teknoloji Yığını
Sistem, modülerliği ve genişletilebilirliği sağlamak adına MVVM ve Strategy Pattern prensipleri üzerine inşa edilmiştir.

*   **Platform & Dil:** iOS (Swift, SwiftUI).
*   **Veri Çıkarım Katmanı:**
    *   **PDFKit:** Seçilebilir PDF'lerde doğal metin erişimi.
    *   **Vision Framework:** Apple'ın on-device OCR teknolojisi ile görsel analizi.
*   **Normalizasyon:** Kaynak bağımsız TextBlock modeli (Metin, Frame koordinatları, Kaynak tipi).

## 4. Gelişmiş Ayrıştırma Stratejileri
Gerçek faturalar (Flo, Hepsiburada, Trendyol vb.) üzerinde yapılan analizler sonucu stratejiler şu şekilde optimize edilmiştir:

### 4.1. ETTN Yakalama (Split-Line Handling)
Özellikle Hepsiburada faturalarında görülen ETTN'nin alt satıra kayması durumu için özel bir mantık geliştirilmiştir.
*   **Kural:** "ETTN" anahtar kelimesinden sonra gelen blok 36 karakter değilse, bir sonraki blok ile birleştirilerek Regex kontrolü yapılır.

### 4.2. Tarih Normalizasyonu
Flo (28-12-2023), Trendyol (06.12.2021) ve A101 (18-04-2023) gibi farklı ayraçlar kullanan yapılar desteklenir.
*   **Kural:** "Düzenleme Tarihi" etiketine en yakın tarih seçilir; saat verisi temizlenir.

### 4.3. Toplam Tutar Tespiti
Hepsiburada'da "Genel Toplam", Trendyol'da "Ödenecek Tutar" gibi farklı isimlendirmelerle başa çıkılır.
*   **Kural:** Sayfanın alt %30'luk bölgesindeki en büyük sayısal değer, anahtar kelime kontrolüyle doğrulanır.

### 4.4. Satıcı Ünvanı Analizi
"A101" (Marka) ile "Yeni Mağazacılık A.Ş." (Ünvan) ayrımı yapılır.
*   **Kural:** Üst %20'lik dilimde "A.Ş.", "LTD." gibi ifadeleri içeren en uzun satır hedeflenir.

## 5. Proje Klasör Yapısı ve Test Metrikleri
Proje, Strategy Pattern sayesinde her alanın (ETTN, Tarih vb.) bağımsız test edilebildiği bir Parser/Strategies klasör yapısına sahiptir.

### Başarı Ölçütleri:
*   **Veri Seti:** 50+ gerçek e-Arşiv faturası üzerinde test.
*   **Performans:** İşlem başına < 1.5 saniye.
*   **Hata Analizi:** Doğruluk oranları Confusion Matrix ile raporlanarak hangi fatura tipinde (PDF vs. Kamera) sapma olduğu ölçülür.

## Sonuç
InvoScanner (V0), deterministik ve cihaz üzerinde çalışan yapısıyla yüksek veri güvenliği sağlarken, modüler strateji yapısıyla ileride hibrit ML modellerine geçiş için sağlam bir temel oluşturmaktadır.


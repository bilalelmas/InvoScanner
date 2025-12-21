# Örnek Faturalar (SampleInvoices)

Bu klasör, projeyi test etmek ve geliştirmek için kullanılan örnek fatura dosyalarını (PDF, JPG, PNG) saklamak içindir.

## Test Sistemine Nasıl Eklenir?

Şu anki `DataDrivenTests` altyapısı doğrudan bu dosyaları okumaz, OCR işleminden geçmiş "Metin Bloklarını" (`TestCases.json` içinde) kullanır.

Bu dosyalardan test verisi oluşturmak için:
1. Uygulamayı simülatörde çalıştırın.
2. Buradaki bir faturayı yükleyin.
3. Xcode konsolunda veya uygulamada çıkan "Ham Metin Bloklarını" kopyalayın.
4. `InvoScannerTests/Resources/TestCases.json` dosyasına yeni bir test senaryosu olarak ekleyin.

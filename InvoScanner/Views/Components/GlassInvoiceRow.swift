import SwiftUI

/// V6.0 Crystal UI: Cam Fatura Listesi Satırı
/// - SavedInvoice veya Invoice modelleriyle çalışabilir
struct GlassInvoiceRow: View {
    // Veri Modeli: SavedInvoice (Persistence) veya Invoice (Transient)
    let supplierName: String
    let totalAmount: Decimal?
    let date: Date?
    let isVerified: Bool
    
    // Opsiyonel Görsel
    var thumbnail: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // İkon / Görsel
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // Onay Rozeti
                if isVerified {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white).padding(2))
                        }
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .frame(width: 48, height: 48)
            
            // Bilgiler
            VStack(alignment: .leading, spacing: 4) {
                Text(supplierName)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                if let date = date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Tutar
            if let amount = totalAmount {
                Text(amount.formatted(.currency(code: "TRY")))
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ZStack {
        Color.indigo
        GlassInvoiceRow(
            supplierName: "TRENDYOL LOJİSTİK",
            totalAmount: 1250.90,
            date: Date(),
            isVerified: true
        )
        .padding()
    }
}

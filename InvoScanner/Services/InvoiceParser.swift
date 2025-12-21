import Foundation

class InvoiceParser {
    
    // Stratejiler
    private let ettnStrategy = ETTNStrategy()
    private let dateStrategy = DateStrategy()
    private let amountStrategy = AmountStrategy()
    private let supplierStrategy = SupplierStrategy()
    
    func parse(blocks: [TextBlock]) -> Invoice {
        var invoice = Invoice()
        invoice.rawBlocks = blocks // Ham veriyi sakla
        
        // Stratejileri Çalıştır
        invoice.ettn = ettnStrategy.extract(from: blocks)
        invoice.date = dateStrategy.extract(from: blocks)
        invoice.totalAmount = amountStrategy.extract(from: blocks)
        invoice.supplierName = supplierStrategy.extract(from: blocks)
        
        return invoice
    }
}

import Foundation

protocol TextExtracting {
    func extractText(from data: Data) -> String
}

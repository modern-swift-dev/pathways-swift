import Foundation
@testable import Pathways
import Testing

struct DateFormatterOptimizationTests {
    @Test func preservesUTCFormattingWithoutFractionalSeconds() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.75)
        #expect(ISO8601DateFormatter.pathwayString(from: date) == "2023-11-14T22:13:20Z")
        #expect(ISO8601DateFormatter.pathwayDate(from: "2023-11-14T22:13:20Z") == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(ISO8601DateFormatter.pathwayDate(from: "2023-11-14T23:13:20+01:00") == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(ISO8601DateFormatter.pathwayDate(from: "invalid") == nil)
    }

    @Test func concurrentFormattingAndParsingPreservesEachDate() async {
        let succeeded = await withTaskGroup(of: Bool.self) { group in
            for index in 0 ..< 100 {
                group.addTask {
                    let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
                    let string = ISO8601DateFormatter.pathwayString(from: date)
                    return ISO8601DateFormatter.pathwayDate(from: string) == date
                }
            }
            for await success in group where !success {
                return false
            }
            return true
        }
        #expect(succeeded)
    }
}

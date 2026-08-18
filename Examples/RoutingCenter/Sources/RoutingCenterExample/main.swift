import Foundation
import Pathways

struct ProductRoute: Pathway {
    static let pattern = "/products/:productID"

    let productID: Int
}

@main enum RoutingCenterExample {
    @MainActor static func main() throws {
        var router = Pathways()

        router.register(host: "example.com", ProductRoute.self) { route, query in
            let campaign = query["campaign", default: "none"]
            print("Open product \(route.productID); campaign: \(campaign)")
        }

        router.register(host: "example.com", path: "/settings") { query in
            let tab = query["tab", default: "general"]
            print("Open settings tab: \(tab)")
        }

        let inputs = [
            "https://example.com/products/42?campaign=summer",
            "https://example.com/settings?tab=privacy",
            "https://other.example/products/42"
        ]

        for input in inputs {
            guard let url = URL(string: input) else {
                continue
            }

            let handled = try router.handle(url)
            print("Handled \(url.absoluteString): \(handled)")
        }
    }
}

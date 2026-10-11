import Foundation
import Pathways
import Testing

@MainActor struct RequestHandlerTests {
    @Test func typedHandlerReceivesTheRouteAndRequest() throws {
        let url = try #require(URL(string: "https://localhost/user/7?tag=a&tag=b&debug"))
        var router = PathwayRouter()
        var received: (route: TestSingleFieldPathway, request: PathwayRequest)?
        router.register(host: "localhost", TestSingleFieldPathway.self) { route, request in
            received = (route, request)
            return .handled
        }

        #expect(try router.handle(url))
        #expect(received?.route.id == 7)
        #expect(received?.request.url == url)
        #expect(received?.request.parameters == ["tag": "b", "debug": ""])
        #expect(received?.request.queryItems == [
            URLQueryItem(name: "tag", value: "a"),
            URLQueryItem(name: "tag", value: "b"),
            URLQueryItem(name: "debug", value: nil)
        ])
    }

    @Test func pathHandlerReceivesTheRequest() throws {
        let url = try #require(URL(string: "myapp:///settings?tab=privacy&tab=account"))
        var router = PathwayRouter()
        var received: PathwayRequest?
        router.register(path: "/settings") { request in
            received = request
            return .handled
        }

        #expect(try router.handle(url))
        #expect(received?.url == url)
        #expect(received?.parameters == ["tab": "account"])
        #expect(received?.queryItems.map(\.value) == ["privacy", "account"])
    }

    @Test(arguments: [false, true]) func fragmentItemsFollowQueryItemsOnlyWhenEnabled(_ supportFragmentParams: Bool) throws {
        let url = try #require(URL(string: "https://localhost/callback?q=1#complete?token=abc&token=def&flag"))
        var router = PathwayRouter()
        var received: PathwayRequest?
        router.register(host: "localhost", path: "/callback", supportFragmentParams: supportFragmentParams) { request in
            received = request
            return .handled
        }

        #expect(try router.handle(url))
        if supportFragmentParams {
            #expect(received?.queryItems == [
                URLQueryItem(name: "q", value: "1"),
                URLQueryItem(name: "token", value: "abc"),
                URLQueryItem(name: "token", value: "def"),
                URLQueryItem(name: "flag", value: nil)
            ])
            #expect(received?.parameters == ["q": "1", "token": "def", "flag": ""])
        } else {
            #expect(received?.queryItems == [URLQueryItem(name: "q", value: "1")])
            #expect(received?.parameters == ["q": "1"])
        }
    }

    @Test func requestHandlersRegisterThroughTheProtocol() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var urls: [URL] = []
        router.register(TestSingleFieldPathway.self, matching: .exact) { _, request in
            urls.append(request.url)
            return .handled
        }
        router.register(host: "localhost", TestMultiFieldPathway.self) { _, request in
            urls.append(request.url)
            return .handled
        }
        router.register(path: "/a", supportFragmentParams: true) { request in
            urls.append(request.url)
            return .handled
        }
        router.register(host: "localhost", path: "/b", matching: .exact) { request in
            urls.append(request.url)
            return .handled
        }

        let addresses = ["https://localhost/user/1", "https://localhost/user/1/type/admin", "https://localhost/a", "https://localhost/b"]
        for address in addresses {
            #expect(try router.handle(#require(URL(string: address))))
        }
        #expect(urls.map(\.absoluteString) == addresses)
    }

    @Test func dictionaryHandlersStillReceiveTheParameterDictionary() throws {
        var router = PathwayRouter()
        var received: [String: String]?
        router.register(host: "localhost", TestSingleFieldPathway.self) { _, parameters in
            received = parameters
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/user/1?a=1&a=2"))))
        #expect(received == ["a": "2"])
    }
}

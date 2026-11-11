import XCTest
@testable import Putio

final class TransferLinkTests: XCTestCase {
    func testParseAcceptsHTTPAndMagnetLinks() throws {
        for text in ["https://example.com/a.torrent", "HTTP://Example.com/x", "magnet:?xt=urn:btih:abc", "magnet:?xt=URN:BTMH:abc"] {
            XCTAssertNotNil(TransferLink.parse(text), text)
        }
        XCTAssertEqual(try XCTUnwrap(TransferLink.parse("magnet:?xt=urn:btih:abc&dn=Name")).displayName, "Name")
        XCTAssertNil(try XCTUnwrap(TransferLink.parse("https://example.com/a")).displayName)
    }

    func testParseFindsTheFirstLinkInSharedText() throws {
        let link = try XCTUnwrap(TransferLink.parse("look:\nmagnet:?xt=urn:btih:abc thanks https://example.com/b"))

        XCTAssertTrue(link.isMagnet)
    }

    func testParseRejectsWhatPutioCannotAdd() {
        for text in ["ftp://example.com/a", "https://", "magnet:?dn=x", "magnet:?xt=urn:sha1:abc", "no link here", ""] {
            XCTAssertNil(TransferLink.parse(text), text)
        }
    }

    func testLongURLsAreTruncatedForDisplay() throws {
        let link = try XCTUnwrap(TransferLink.parse("https://example.com/" + String(repeating: "a", count: 300)))

        XCTAssertEqual(link.truncatedURL.count, 201)
        XCTAssertTrue(link.truncatedURL.hasSuffix("…"))
    }

    func testIncomingRoutesOnlyMagnetsAndTheAppLink() throws {
        let web = try XCTUnwrap(URL(string: "https://put.io/transfers/add?url=https%3A%2F%2Fexample.com%2Fa"))
        XCTAssertNil(TransferLink.incoming(web), "a web link must not start a transfer")
        XCTAssertNil(TransferLink.incoming(try XCTUnwrap(URL(string: "putio://history"))))

        let shared = try XCTUnwrap(URL(string: "putio://transfers/add?url=https%3A%2F%2Fexample.com%2Fa"))
        XCTAssertEqual(TransferLink.incoming(shared), .link(try XCTUnwrap(TransferLink.parse("https://example.com/a"))))
        XCTAssertEqual(TransferLink.incoming(try XCTUnwrap(URL(string: "magnet:?xt=urn:btih:abc"))), .link(try XCTUnwrap(TransferLink.parse("magnet:?xt=urn:btih:abc"))))

        XCTAssertEqual(TransferLink.incoming(try XCTUnwrap(URL(string: "putio://transfers/add"))), .unsupported)
        XCTAssertEqual(TransferLink.incoming(try XCTUnwrap(URL(string: "putio://transfers/add?url=ftp%3A%2F%2Fx"))), .unsupported)
        XCTAssertEqual(TransferLink.incoming(try XCTUnwrap(URL(string: "magnet:?dn=x"))), .unsupported)
    }

    func testAppURLRoundTripsAMagnetWithReservedCharacters() throws {
        let magnet = "magnet:?xt=urn:btih:abc&dn=Some%20Show%20S01%3DE02&tr=udp%3A%2F%2Ftracker.example%3A80%2Fannounce"
        let link = try XCTUnwrap(TransferLink.parse(magnet))

        XCTAssertEqual(TransferLink.incoming(link.appURL), .link(link))
        XCTAssertEqual(link.displayName, "Some Show S01=E02")
    }
}

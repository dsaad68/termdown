import XCTest
@testable import termdownCore

/// Tests for the Color abstraction + truecolor emission (Phase 2).
final class ColorTests: XCTestCase {

    // Restore the global flag after each test so order doesn't matter.
    override func tearDown() {
        Ansi.truecolor = false
        super.tearDown()
    }

    func test256ModeEmitsPaletteIndex() {
        Ansi.truecolor = false
        XCTAssertEqual(Ansi.fg(.x256(183)), [38, 5, 183])
        XCTAssertEqual(Ansi.bg(.x256(238)), [48, 5, 238])
    }

    func testTruecolorEmitsExactRGBForPaletteIndex() {
        Ansi.truecolor = true
        // 183 is cube index → (215,175,255).
        XCTAssertEqual(Ansi.fg(.x256(183)), [38, 2, 215, 175, 255])
    }

    func testRGBColorEmitsTruecolorWhenSupported() {
        Ansi.truecolor = true
        XCTAssertEqual(Ansi.fg(.rgb(10, 20, 30)), [38, 2, 10, 20, 30])
        XCTAssertEqual(Ansi.bg(.rgb(200, 100, 50)), [48, 2, 200, 100, 50])
    }

    func testRGBColorDownsamplesIn256Mode() {
        Ansi.truecolor = false
        // An RGB triple becomes a [38,5,n] palette index, never a 24-bit sequence.
        let codes = Ansi.fg(.rgb(215, 175, 255))
        XCTAssertEqual(codes.count, 3)
        XCTAssertEqual(Array(codes.prefix(2)), [38, 5])
        XCTAssertEqual(codes[2], 183)   // exact cube color round-trips to its index
    }

    func testPalette256RGBCubeAndGray() {
        XCTAssertTrue(Ansi.palette256RGB(16) == (0, 0, 0))         // cube black
        XCTAssertTrue(Ansi.palette256RGB(231) == (255, 255, 255)) // cube white
        XCTAssertTrue(Ansi.palette256RGB(244) == (128, 128, 128)) // grayscale
    }

    func testNearest256PicksCubeOrGray() {
        XCTAssertEqual(Ansi.nearest256(0, 0, 0), 16)
        XCTAssertEqual(Ansi.nearest256(255, 255, 255), 231)
        XCTAssertEqual(Ansi.nearest256(128, 128, 128), 244)   // closest to the gray ramp
    }

    func testIntegerLiteralBuildsX256() {
        let c: Ansi.Color = 200
        XCTAssertEqual(c, .x256(200))
    }
}

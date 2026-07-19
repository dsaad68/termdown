import XCTest
@testable import termdown

/// Mouse-tracking scopes must nest. The file finder opens *inside* the running
/// pager (`T`), and before the scope stack its unconditional teardown left the
/// pager with the mouse dead for the rest of the session.
final class MouseTrackingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Terminal.forceDisableMouseTracking()
    }

    override func tearDown() {
        Terminal.forceDisableMouseTracking()
        super.tearDown()
    }

    func testBalancedEnableDisable() {
        XCTAssertEqual(Terminal.mouseTrackingDepth, 0)
        Terminal.enableMouseTracking()
        XCTAssertEqual(Terminal.mouseTrackingDepth, 1)
        Terminal.disableMouseTracking()
        XCTAssertEqual(Terminal.mouseTrackingDepth, 0)
    }

    /// The reported bug: pager enables, finder opens and closes, pager must
    /// still have tracking. Previously the inner disable dropped it to nothing.
    func testNestedScopeKeepsOuterTrackingAlive() {
        Terminal.enableMouseTracking(drag: true)   // pager
        Terminal.enableMouseTracking()             // finder opened with `T`
        XCTAssertEqual(Terminal.mouseTrackingDepth, 2)
        Terminal.disableMouseTracking()            // finder closes
        XCTAssertEqual(Terminal.mouseTrackingDepth, 1, "the pager's scope must survive")
        Terminal.disableMouseTracking()            // pager exits
        XCTAssertEqual(Terminal.mouseTrackingDepth, 0)
    }

    func testUnbalancedDisableIsInert() {
        // Extra teardowns must not drive the depth negative or emit stray modes.
        Terminal.disableMouseTracking()
        Terminal.disableMouseTracking()
        XCTAssertEqual(Terminal.mouseTrackingDepth, 0)
    }

    /// The exit paths (`disableRawMode`, atexit, SIGINT) unwind the process, not
    /// a scope — they must tear down whatever depth is outstanding or `?1000h`
    /// leaks into the user's shell.
    func testForceDisableClearsEveryScope() {
        Terminal.enableMouseTracking(drag: true)
        Terminal.enableMouseTracking()
        Terminal.enableMouseTracking()
        XCTAssertEqual(Terminal.mouseTrackingDepth, 3)
        Terminal.forceDisableMouseTracking()
        XCTAssertEqual(Terminal.mouseTrackingDepth, 0)
    }

    func testDragScopeIndependentOfPlainScope() {
        // A plain scope closing must not retract the drag mode a deeper scope
        // still wants, and vice versa.
        Terminal.enableMouseTracking(drag: true)
        Terminal.enableMouseTracking(drag: false)
        Terminal.disableMouseTracking()
        XCTAssertEqual(Terminal.mouseTrackingDepth, 1)
        Terminal.disableMouseTracking()
        XCTAssertEqual(Terminal.mouseTrackingDepth, 0)
    }

    // MARK: - LiveGrep click mapping

    func testHitIndexSkipsHeaderRows() {
        // Screen rows 1...headerLines are chrome; the first result is the row
        // right below them.
        for y in 1...LiveGrep.headerLines {
            XCTAssertNil(LiveGrep.hitIndex(atRow: y, scroll: 0, viewport: 10, count: 5), "row \(y)")
        }
        XCTAssertEqual(LiveGrep.hitIndex(atRow: LiveGrep.headerLines + 1,
                                         scroll: 0, viewport: 10, count: 5), 0)
    }

    func testHitIndexAppliesScrollAndBounds() {
        XCTAssertEqual(LiveGrep.hitIndex(atRow: LiveGrep.headerLines + 3,
                                         scroll: 10, viewport: 10, count: 50), 12)
        // Past the last hit, and past the viewport, are both misses.
        XCTAssertNil(LiveGrep.hitIndex(atRow: LiveGrep.headerLines + 4,
                                       scroll: 0, viewport: 10, count: 3))
        XCTAssertNil(LiveGrep.hitIndex(atRow: LiveGrep.headerLines + 11,
                                       scroll: 0, viewport: 10, count: 50))
    }
}

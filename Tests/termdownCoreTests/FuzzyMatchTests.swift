import XCTest
@testable import termdownCore

final class FuzzyMatchTests: XCTestCase {

    func testMatchExact() {
        let result = FuzzyMatch.match("test", against: "test")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.matchedIndices, [0, 1, 2, 3])
    }

    func testMatchCaseInsensitive() {
        let result1 = FuzzyMatch.match("TEST", against: "test")
        XCTAssertNotNil(result1)

        let result2 = FuzzyMatch.match("test", against: "TEST")
        XCTAssertNotNil(result2)
    }

    func testMatchSubstring() {
        let result = FuzzyMatch.match("est", against: "test")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.matchedIndices, [1, 2, 3])
    }

    func testMatchFuzzy() {
        let result = FuzzyMatch.match("tst", against: "test")
        XCTAssertNotNil(result)
        // Should match t, s, t (skipping e)
    }

    func testNoMatch() {
        let result = FuzzyMatch.match("xyz", against: "test")
        XCTAssertNil(result)
    }

    func testMatchEmptyQuery() {
        let result = FuzzyMatch.match("", against: "test")
        XCTAssertNil(result)
    }

    func testMatchPathSeparators() {
        let result = FuzzyMatch.match("src/file", against: "src/myfile.swift")
        XCTAssertNotNil(result)
    }

    func testMatchCamelCase() {
        let result = FuzzyMatch.match("MF", against: "MyFile")
        XCTAssertNotNil(result)
    }

    func testFilterAndSort() {
        let items = ["test.swift", "testing.md", "other.txt"]
        let results = FuzzyMatch.filterAndSort(items, query: "test")

        XCTAssertEqual(results.count, 2)
        let itemNames = results.map { $0.item }
        XCTAssertTrue(itemNames.contains("test.swift"))
        XCTAssertTrue(itemNames.contains("testing.md"))
        XCTAssertFalse(itemNames.contains("other.txt"))
    }

    func testFilterAndSortEmptyQuery() {
        let items = ["test.swift", "testing.md", "other.txt"]
        let results = FuzzyMatch.filterAndSort(items, query: "")

        // Should return all items with empty indices when query is empty
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.map { $0.indices }, [[], [], []])
    }

    func testFilterAndSortRanking() {
        let items = ["test.swift", "test_file.swift", "mytest.swift"]
        let results = FuzzyMatch.filterAndSort(items, query: "test")

        // "test.swift" should rank higher than "mytest.swift" because it starts with the query
        XCTAssertEqual(results.first?.item, "test.swift")
    }

    func testMatchScoring() {
        let exact = FuzzyMatch.match("test", against: "test")
        let fuzzy = FuzzyMatch.match("tst", against: "test")

        XCTAssertNotNil(exact)
        XCTAssertNotNil(fuzzy)

        // Exact match should have higher score than fuzzy match
        XCTAssertTrue(exact!.score > fuzzy!.score)
    }
}

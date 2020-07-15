import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(swift_for_bazel_reTests.allTests),
    ]
}
#endif

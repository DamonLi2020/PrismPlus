import Testing

@testable import PrismPlus

struct LaTeXSourceReadinessTests {
    @Test("Incomplete delimiters defer automatic compilation")
    func detectsIncompleteSource() {
        #expect(!LaTeXSourceReadiness.isReady(#"\section{Incomplete"#))
        #expect(LaTeXSourceReadiness.isReady(#"\section{Complete}"#))
        #expect(LaTeXSourceReadiness.isReady(#"Escaped \{ brace"#))
        #expect(LaTeXSourceReadiness.isReady("% ignored { comment\nText"))
    }
}

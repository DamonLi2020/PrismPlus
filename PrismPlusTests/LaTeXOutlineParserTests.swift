import Testing

@testable import PrismPlus

struct LaTeXOutlineParserTests {
    @Test("Standard and starred headings form a navigable hierarchy")
    func parsesHeadingHierarchy() {
        let source = #"""
            % \section{Ignored comment}
            \section{Introduction}
            \subsection*{Background}
            \subsubsection{Prior \textbf{Work}}
            \section[Short title]{A Longer Conclusion}
            """#

        let outline = LaTeXOutlineParser.parse(source)

        #expect(outline.count == 2)
        #expect(outline[0].title == "Introduction")
        #expect(outline[0].line == 2)
        #expect(outline[0].children.count == 1)
        #expect(outline[0].children[0].title == "Background")
        #expect(outline[0].children[0].isUnnumbered)
        #expect(outline[0].children[0].children[0].title == "Prior Work")
        #expect(outline[1].title == "A Longer Conclusion")
        #expect(outline[1].line == 5)
    }

    @Test("Book-level headings and Unicode titles are supported")
    func parsesBookHierarchy() {
        let source = #"""
            \part{Foundations}
            \chapter{分析}
            \section{Results}
            \paragraph{Observation}
            """#

        let outline = LaTeXOutlineParser.parse(source)

        #expect(outline[0].title == "Foundations")
        #expect(outline[0].children[0].title == "分析")
        #expect(outline[0].children[0].children[0].title == "Results")
        #expect(outline[0].children[0].children[0].children[0].title == "Observation")
    }
}

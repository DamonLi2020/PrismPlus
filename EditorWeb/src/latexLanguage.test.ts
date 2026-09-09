import { describe, expect, it } from "vitest";
import {
  autoClosingPairs,
  completionItems,
  formatLaTeX,
} from "./latexLanguage";

describe("LaTeX language intelligence", () => {
  it("returns documented snippets for a command prefix", () => {
    const results = completionItems("\\sec");

    expect(results[0]?.label).toBe("\\section");
    expect(results[0]?.insertText).toBe("\\section{${1:title}}");
    expect(results.some((item) => item.label === "\\subsection")).toBe(false);
    expect(completionItems("\\alp")[0]?.label).toBe("\\alpha");
    expect(completionItems("\\begin{").length).toBeGreaterThan(5);
  });

  it("defines IDE-style structural pairs", () => {
    expect(autoClosingPairs).toContainEqual({ open: "{", close: "}" });
    expect(autoClosingPairs).toContainEqual({ open: "\"", close: "\"" });
    expect(autoClosingPairs).toContainEqual({ open: "\\[", close: "\\]" });
  });

  it("formats nested environments and removes trailing whitespace", () => {
    const source = [
      "\\begin{document}",
      "\\section{Intro}   ",
      "\\begin{itemize}",
      "\\item One",
      "\\end{itemize}",
      "\\end{document}",
    ].join("\n");

    expect(formatLaTeX(source)).toBe(
      [
      "\\begin{document}",
      "\\section{Intro}",
      "\\begin{itemize}",
      "  \\item One",
      "\\end{itemize}",
        "\\end{document}",
        "",
      ].join("\n"),
    );
  });
});

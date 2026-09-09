import { describe, expect, it } from "vitest";
import {
  autoClosingPairs,
  completionContext,
  completionItems,
  completionItemsForContext,
  formatLaTeX,
  shouldTriggerSuggestions,
} from "./latexLanguage";

describe("LaTeX language intelligence", () => {
  it("returns documented snippets for a command prefix", () => {
    const results = completionItems("\\sec");

    expect(results[0]?.label).toBe("\\section");
    expect(results[0]?.insertText).toBe("\\section{${1:title}}");
    expect(results[0]?.documentation).toContain("Creates a numbered section");
    expect(results[0]?.documentation).toContain("```latex\n\\section{title}\n```");
    expect(results[0]?.documentation).not.toContain("${1:");
    expect(results.some((item) => item.label === "\\subsection")).toBe(false);
    expect(completionItems("\\alp")[0]?.label).toBe("\\alpha");
    expect(completionItems("\\begin{").length).toBeGreaterThan(5);
  });

  it("defines IDE-style structural pairs", () => {
    expect(autoClosingPairs).toContainEqual({ open: "{", close: "}" });
    expect(autoClosingPairs).toContainEqual({ open: "\"", close: "\"" });
    expect(autoClosingPairs).toContainEqual({ open: "\\[", close: "\\]" });
  });

  it("detects command and LaTeX argument completion contexts", () => {
    expect(completionContext("\\sec", "")).toEqual({
      kind: "command",
      prefix: "\\sec",
      consumeAfterCursor: 0,
    });
    expect(completionContext("\\begin{it", "}")).toEqual({
      kind: "beginEnvironment",
      prefix: "it",
      consumeAfterCursor: 1,
    });
    expect(completionContext("\\usepackage{am", "}")).toEqual({
      kind: "package",
      prefix: "am",
      consumeAfterCursor: 1,
    });
    expect(completionContext("ordinary text", "")).toBeUndefined();
  });

  it("provides context-specific environments, packages, and classes", () => {
    const environment = completionContext("\\begin{ali", "}")!;
    const packageContext = completionContext("\\usepackage{am", "}")!;
    const classContext = completionContext("\\documentclass{re", "}")!;

    expect(completionItemsForContext(environment)[0]?.label).toBe("align");
    expect(completionItemsForContext(environment)[0]?.insertText).toContain("\\end{align}");
    expect(completionItemsForContext(packageContext).map((item) => item.label)).toContain("amsmath");
    expect(completionItemsForContext(classContext).map((item) => item.label)).toContain("report");
  });

  it("explicitly opens suggestions at LaTeX trigger points", () => {
    expect(shouldTriggerSuggestions("\\", "\\")).toBe(true);
    expect(shouldTriggerSuggestions("\\begin{", "{")).toBe(true);
    expect(shouldTriggerSuggestions("\\usepackage{", "{")).toBe(true);
    expect(shouldTriggerSuggestions("plain {", "{")).toBe(false);
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

import { describe, expect, it } from "vitest";
import {
  autoClosingPairs,
  completionContext,
  completionItems,
  completionItemsForContext,
  diagnosticMarkers,
  formatLaTeX,
  shouldDeferCompilation,
  shouldTriggerSuggestions,
  sourcePositionAfterChange,
} from "./latexLanguage";

describe("LaTeX language intelligence", () => {
  it("returns documented snippets for a command prefix", () => {
    const results = completionItems("\\sec");

    expect(results[0]?.label).toBe("\\section");
    expect(results[0]?.insertText).toBe("\\section{${1:title}}");
    expect(results[0]?.documentation).toContain("Creates a numbered section");
    expect(results[0]?.documentation).toContain("```latex\n\\section{title}\n```");
    expect(results[0]?.documentation).not.toContain("${1:");
    expect(results[0]?.signature).toBe("\\section{title}");
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

  it("defers compilation while the user is choosing an incomplete completion", () => {
    expect(shouldDeferCompilation("\\s", "")).toBe(true);
    expect(shouldDeferCompilation("\\section", "")).toBe(true);
    expect(shouldDeferCompilation("\\begin{ali", "}")).toBe(true);
    expect(shouldDeferCompilation("\\alpha", "")).toBe(false);
    expect(shouldDeferCompilation("ordinary text", "")).toBe(false);
    expect(shouldDeferCompilation("\\unknowncommand", "")).toBe(false);
  });

  it("derives the post-edit caret before Monaco publishes its cursor event", () => {
    expect(sourcePositionAfterChange(4, 3, "sec")).toEqual({
      lineNumber: 4,
      column: 6,
    });
    expect(sourcePositionAfterChange(4, 3, "section{title}\nnext")).toEqual({
      lineNumber: 5,
      column: 5,
    });
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

  it("reflows prose paragraphs without breaking LaTeX commands", () => {
    const source = [
      "\\begin{document}",
      "\\section{Introduction}",
      "This is a deliberately long prose paragraph that should wrap into readable source lines.",
      "\\textbf{This command line remains intact even when it is longer than the selected width.}",
      "\\end{document}",
    ].join("\n");

    expect(formatLaTeX(source, 42)).toBe(
      [
        "\\begin{document}",
        "\\section{Introduction}",
        "This is a deliberately long prose",
        "  paragraph that should wrap into readable",
        "  source lines.",
        "\\textbf{This command line remains intact even when it is longer than the selected width.}",
        "\\end{document}",
        "",
      ].join("\n"),
    );
  });

  it("preserves comments, equations, and table rows while formatting", () => {
    const source = [
      "% A long comment remains exactly as the author wrote it instead of being reflowed.",
      "\\begin{align}",
      "value &= first + second + third + fourth + fifth \\\\",
      "\\end{align}",
      "\\begin{tabular}{ll}",
      "A very long cell & Another cell \\\\",
      "\\end{tabular}",
    ].join("\n");

    const formatted = formatLaTeX(source, 32);

    expect(formatted).toContain("% A long comment remains exactly as the author wrote it");
    expect(formatted).toContain("  value &= first + second + third + fourth + fifth \\\\");
    expect(formatted).toContain("  A very long cell & Another cell \\\\");
  });

  it("maps line diagnostics to clamped red and yellow source markers", () => {
    const markers = diagnosticMarkers(
      [
        { severity: "error", message: "Undefined control sequence.", line: 2 },
        { severity: "warning", message: "Reference is undefined.", line: 99 },
        { severity: "warning", message: "General warning.", line: null },
      ],
      ["first", "  \\badcommand", "last"],
    );

    expect(markers).toEqual([
      {
        severity: "error",
        message: "Undefined control sequence.",
        startLineNumber: 2,
        startColumn: 3,
        endLineNumber: 2,
        endColumn: 14,
      },
      {
        severity: "warning",
        message: "Reference is undefined.",
        startLineNumber: 3,
        startColumn: 1,
        endLineNumber: 3,
        endColumn: 5,
      },
    ]);
  });
});

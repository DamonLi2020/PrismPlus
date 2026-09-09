export interface CompletionItem {
  label: string;
  detail: string;
  documentation: string;
  insertText: string;
  signature: string;
}

export type CompletionContextKind =
  | "command"
  | "beginEnvironment"
  | "endEnvironment"
  | "package"
  | "documentClass";

export interface CompletionContext {
  kind: CompletionContextKind;
  prefix: string;
  consumeAfterCursor: number;
}

export interface EditorDiagnostic {
  severity: "error" | "warning";
  message: string;
  line?: number | null;
}

export interface DiagnosticMarker {
  severity: "error" | "warning";
  message: string;
  startLineNumber: number;
  startColumn: number;
  endLineNumber: number;
  endColumn: number;
}

export const autoClosingPairs = [
  { open: "\\left(", close: "\\right)" },
  { open: "\\left[", close: "\\right]" },
  { open: "\\left\\{", close: "\\right\\}" },
  { open: "\\(", close: "\\)" },
  { open: "\\[", close: "\\]" },
  { open: "{", close: "}" },
  { open: "[", close: "]" },
  { open: "(", close: ")" },
  { open: "\"", close: "\"" },
  { open: "$", close: "$" },
  { open: "`", close: "'" },
];

const completions: CompletionItem[] = [
  snippet("\\section", "Section", "\\section{${1:title}}", "Creates a numbered section."),
  snippet(
    "\\section*",
    "Unnumbered section",
    "\\section*{${1:title}}",
    "Creates a section without a number or table-of-contents entry.",
  ),
  snippet("\\subsection", "Subsection", "\\subsection{${1:title}}", "Creates a numbered subsection."),
  snippet(
    "\\subsubsection",
    "Subsubsection",
    "\\subsubsection{${1:title}}",
    "Creates a numbered third-level section.",
  ),
  snippet(
    "\\documentclass",
    "Document class",
    "\\documentclass[${1:options}]{${2:article}}",
    "Selects the document type and its optional class settings.",
  ),
  snippet(
    "\\usepackage",
    "Package import",
    "\\usepackage[${1:options}]{${2:package}}",
    "Loads a LaTeX package with optional configuration.",
  ),
  snippet(
    "\\begin",
    "Environment",
    "\\begin{${1:environment}}\n\t$0\n\\end{${1:environment}}",
    "Creates a matched LaTeX environment and places the cursor inside it.",
  ),
  snippet("\\begin{document}", "Document environment", "\\begin{document}\n$0\n\\end{document}"),
  snippet("\\begin{itemize}", "Bulleted list", "\\begin{itemize}\n\t\\item ${1:item}\n\\end{itemize}"),
  snippet("\\begin{enumerate}", "Numbered list", "\\begin{enumerate}\n\t\\item ${1:item}\n\\end{enumerate}"),
  snippet("\\begin{equation}", "Numbered equation", "\\begin{equation}\n\t${1:expression}\n\\end{equation}"),
  snippet("\\begin{align}", "Aligned equations", "\\begin{align}\n\t${1:left} &= ${2:right} \\\\\n\\end{align}"),
  snippet("\\begin{figure}", "Figure", "\\begin{figure}[${1:htbp}]\n\t\\centering\n\t$0\n\t\\caption{${2:caption}}\n\t\\label{fig:${3:key}}\n\\end{figure}"),
  snippet("\\begin{table}", "Table", "\\begin{table}[${1:htbp}]\n\t\\centering\n\t$0\n\t\\caption{${2:caption}}\n\t\\label{tab:${3:key}}\n\\end{table}"),
  snippet("\\item", "List item", "\\item ${1:text}"),
  snippet("\\textbf", "Bold text", "\\textbf{${1:text}}"),
  snippet("\\textit", "Italic text", "\\textit{${1:text}}"),
  snippet("\\emph", "Emphasized text", "\\emph{${1:text}}"),
  snippet("\\label", "Cross-reference label", "\\label{${1:key}}"),
  snippet("\\ref", "Cross-reference", "\\ref{${1:key}}"),
  snippet("\\cite", "Citation", "\\cite{${1:key}}"),
  snippet("\\includegraphics", "Image", "\\includegraphics[${1:width=\\linewidth}]{${2:path}}"),
  snippet("\\input", "Insert another source file", "\\input{${1:path}}"),
  snippet("\\include", "Include another source file", "\\include{${1:path}}"),
  snippet("\\bibliography", "Bibliography database", "\\bibliography{${1:references}}"),
  snippet("\\bibliographystyle", "Bibliography style", "\\bibliographystyle{${1:plain}}"),
  snippet("\\frac", "Fraction", "\\frac{${1:numerator}}{${2:denominator}}"),
  snippet("\\sqrt", "Square root", "\\sqrt{${1:value}}"),
  snippet("\\sum", "Summation", "\\sum_{${1:i=1}}^{${2:n}} ${3:expression}"),
  snippet("\\prod", "Product", "\\prod_{${1:i=1}}^{${2:n}} ${3:expression}"),
  snippet("\\int", "Integral", "\\int_{${1:a}}^{${2:b}} ${3:f(x)}\\,d${4:x}"),
  snippet("\\lim", "Limit", "\\lim_{${1:x \\to a}} ${2:f(x)}"),
  snippet("\\left", "Automatically sized delimiters", "\\left${1:(} $0 \\right${2:)}"),
  snippet("\\mathbf", "Bold math", "\\mathbf{${1:value}}"),
  snippet("\\mathbb", "Blackboard bold math", "\\mathbb{${1:R}}"),
  snippet("\\mathrm", "Roman math text", "\\mathrm{${1:text}}"),
  snippet("\\text", "Text inside math", "\\text{${1:text}}"),
  snippet("\\alpha", "Greek letter alpha", "\\alpha"),
  snippet("\\beta", "Greek letter beta", "\\beta"),
  snippet("\\gamma", "Greek letter gamma", "\\gamma"),
  snippet("\\delta", "Greek letter delta", "\\delta"),
  snippet("\\epsilon", "Greek letter epsilon", "\\epsilon"),
  snippet("\\theta", "Greek letter theta", "\\theta"),
  snippet("\\lambda", "Greek letter lambda", "\\lambda"),
  snippet("\\mu", "Greek letter mu", "\\mu"),
  snippet("\\pi", "Greek letter pi", "\\pi"),
  snippet("\\sigma", "Greek letter sigma", "\\sigma"),
  snippet("\\phi", "Greek letter phi", "\\phi"),
  snippet("\\omega", "Greek letter omega", "\\omega"),
  snippet("\\infty", "Infinity symbol", "\\infty"),
  snippet("\\partial", "Partial derivative symbol", "\\partial"),
  snippet("\\nabla", "Nabla symbol", "\\nabla"),
  snippet("\\cdot", "Centered multiplication dot", "\\cdot"),
  snippet("\\times", "Multiplication sign", "\\times"),
  snippet("\\leq", "Less than or equal", "\\leq"),
  snippet("\\geq", "Greater than or equal", "\\geq"),
  snippet("\\neq", "Not equal", "\\neq"),
  snippet("\\approx", "Approximately equal", "\\approx"),
  snippet("\\in", "Set membership", "\\in"),
  snippet("\\subset", "Subset", "\\subset"),
  snippet("\\cup", "Set union", "\\cup"),
  snippet("\\cap", "Set intersection", "\\cap"),
  snippet("\\forall", "For all", "\\forall"),
  snippet("\\exists", "There exists", "\\exists"),
  snippet("\\rightarrow", "Right arrow", "\\rightarrow"),
  snippet("\\Rightarrow", "Right double arrow", "\\Rightarrow"),
  snippet("\\title", "Document title", "\\title{${1:title}}"),
  snippet("\\author", "Document author", "\\author{${1:author}}"),
  snippet("\\date", "Document date", "\\date{${1:\\today}}"),
  snippet("\\maketitle", "Render title", "\\maketitle"),
];

const environments = [
  environment("align", "Aligned equations", "${1:left} &= ${2:right} \\\\"),
  environment("align*", "Unnumbered aligned equations", "${1:left} &= ${2:right} \\\\"),
  environment("document", "Document body"),
  environment("enumerate", "Numbered list", "\\item ${1:item}"),
  environment("equation", "Numbered equation", "${1:expression}"),
  environment("equation*", "Unnumbered equation", "${1:expression}"),
  environment("figure", "Floating figure", "\\centering\n\\caption{${1:caption}}\n\\label{fig:${2:key}}"),
  environment("gather", "Gathered equations", "${1:expression} \\\\"),
  environment("itemize", "Bulleted list", "\\item ${1:item}"),
  environment("matrix", "Matrix", "${1:a} & ${2:b} \\\\\n${3:c} & ${4:d}"),
  environment("multicols", "Multiple columns", "$0"),
  environment("proof", "Proof", "$0"),
  environment("table", "Floating table", "\\centering\n\\caption{${1:caption}}\n\\label{tab:${2:key}}"),
  environment("tabular", "Table grid", "${1:lcr}\n${2:content}"),
  environment("theorem", "Theorem", "$0"),
  environment("tikzcd", "Commutative diagram", "$0"),
];

const packages = [
  "amsmath",
  "amssymb",
  "biblatex",
  "booktabs",
  "cleveref",
  "enumitem",
  "fontspec",
  "geometry",
  "graphicx",
  "hyperref",
  "mathtools",
  "microtype",
  "multicol",
  "tikz",
  "tikz-cd",
  "xcolor",
];

const documentClasses = ["article", "book", "letter", "memoir", "report", "standalone"];

export function completionItems(prefix: string): CompletionItem[] {
  if (!prefix.startsWith("\\")) return [];
  return completions.filter((item) => item.label.startsWith(prefix));
}

export function completionContext(
  lineBeforeCursor: string,
  lineAfterCursor: string,
): CompletionContext | undefined {
  const argumentContexts: Array<[RegExp, CompletionContextKind]> = [
    [/\\begin\{([^{}]*)$/, "beginEnvironment"],
    [/\\end\{([^{}]*)$/, "endEnvironment"],
    [/\\usepackage(?:\[[^\]]*\])?\{([^{}]*)$/, "package"],
    [/\\documentclass(?:\[[^\]]*\])?\{([^{}]*)$/, "documentClass"],
  ];

  for (const [pattern, kind] of argumentContexts) {
    const match = lineBeforeCursor.match(pattern);
    if (match) {
      return {
        kind,
        prefix: match[1] ?? "",
        consumeAfterCursor: lineAfterCursor.startsWith("}") ? 1 : 0,
      };
    }
  }

  const command = lineBeforeCursor.match(/\\[A-Za-z@]*$/)?.[0];
  if (!command) return undefined;
  return { kind: "command", prefix: command, consumeAfterCursor: 0 };
}

export function completionItemsForContext(context: CompletionContext): CompletionItem[] {
  switch (context.kind) {
    case "command":
      return completionItems(context.prefix);
    case "beginEnvironment":
      return environments.filter((item) => item.label.startsWith(context.prefix));
    case "endEnvironment":
      return environments
        .filter((item) => item.label.startsWith(context.prefix))
        .map((item) =>
          value(
            item.label,
            "Close environment",
            `${item.label}}`,
            `Closes the current ${item.label} environment.`,
            `\\end{${item.label}}`,
          ),
        );
    case "package":
      return packages
        .filter((name) => name.startsWith(context.prefix))
        .map((name) =>
          value(
            name,
            "LaTeX package",
            `${name}}`,
            `Loads the ${name} package in the document preamble.`,
            `\\usepackage{${name}}`,
          ),
        );
    case "documentClass":
      return documentClasses
        .filter((name) => name.startsWith(context.prefix))
        .map((name) =>
          value(
            name,
            "Document class",
            `${name}}`,
            `Uses ${name} as the document's overall layout class.`,
            `\\documentclass{${name}}`,
          ),
        );
  }
}

export function shouldTriggerSuggestions(lineBeforeCursor: string, typedText: string): boolean {
  if (typedText === "\\") return !lineBeforeCursor.endsWith("\\\\");
  if (typedText !== "{") return false;
  const context = completionContext(lineBeforeCursor, "");
  return context !== undefined && context.kind !== "command";
}

export function shouldDeferCompilation(
  lineBeforeCursor: string,
  lineAfterCursor: string,
): boolean {
  const context = completionContext(lineBeforeCursor, lineAfterCursor);
  if (!context) return false;
  const items = completionItemsForContext(context);
  if (items.length === 0) return false;
  if (context.kind !== "command") return true;

  const exactMatch = items.find((item) => item.label === context.prefix);
  if (!exactMatch) return true;
  return exactMatch.insertText !== exactMatch.label;
}

export function sourcePositionAfterChange(
  startLineNumber: number,
  startColumn: number,
  insertedText: string,
): { lineNumber: number; column: number } {
  const insertedLines = insertedText.split(/\r?\n/);
  if (insertedLines.length === 1) {
    return {
      lineNumber: startLineNumber,
      column: startColumn + insertedLines[0].length,
    };
  }
  return {
    lineNumber: startLineNumber + insertedLines.length - 1,
    column: (insertedLines.at(-1)?.length ?? 0) + 1,
  };
}

export function diagnosticMarkers(
  diagnostics: EditorDiagnostic[],
  sourceLines: string[],
): DiagnosticMarker[] {
  if (sourceLines.length === 0) return [];
  return diagnostics.flatMap((diagnostic) => {
    if (diagnostic.line == null || !Number.isFinite(diagnostic.line)) return [];
    const line = Math.min(Math.max(Math.trunc(diagnostic.line), 1), sourceLines.length);
    const content = sourceLines[line - 1] ?? "";
    const firstContentIndex = content.search(/\S/);
    const startColumn = firstContentIndex >= 0 ? firstContentIndex + 1 : 1;
    return [{
      severity: diagnostic.severity,
      message: diagnostic.message,
      startLineNumber: line,
      startColumn,
      endLineNumber: line,
      endColumn: Math.max(startColumn + 1, content.length + 1),
    }];
  });
}

const protectedEnvironments = new Set([
  "align",
  "align*",
  "aligned",
  "array",
  "cases",
  "equation",
  "equation*",
  "gather",
  "gather*",
  "lstlisting",
  "matrix",
  "multline",
  "multline*",
  "pmatrix",
  "split",
  "tabular",
  "tabularx",
  "tikzcd",
  "tikzpicture",
  "verbatim",
  "Verbatim",
]);

export function formatLaTeX(source: string, lineWidth = 88): string {
  const lines = source.split(/\r?\n/);
  const output: string[] = [];
  let indentation = 0;
  const environments: string[] = [];
  let paragraphWords: string[] = [];
  let paragraphIndentation = 0;

  const flushParagraph = () => {
    if (paragraphWords.length === 0) return;
    output.push(...wrapWords(paragraphWords, paragraphIndentation, lineWidth));
    paragraphWords = [];
  };

  for (const originalLine of lines) {
    const line = originalLine.trimEnd().trimStart();
    if (line.length === 0) {
      flushParagraph();
      if (output.length > 0 && output.at(-1) !== "") output.push("");
      continue;
    }

    const closing = line.match(/^\\end\{([^}]+)\}/)?.[1];
    const opening = line.match(/^\\begin\{([^}]+)\}/)?.[1];
    const isProtected = environments.some((name) => protectedEnvironments.has(name));
    const isStructural =
      line.startsWith("\\") ||
      line.startsWith("%") ||
      isProtected ||
      line.includes("&") ||
      line.endsWith("\\\\");

    if (isStructural) {
      flushParagraph();
      if (closing && closing !== "document") indentation = Math.max(0, indentation - 1);
      output.push(`${"  ".repeat(indentation)}${line}`);
    } else {
      if (paragraphWords.length === 0) paragraphIndentation = indentation;
      paragraphWords.push(...line.split(/\s+/));
    }

    if (
      opening &&
      opening !== "document" &&
      !line.includes(`\\end{${opening}}`)
    ) {
      indentation += 1;
      environments.push(opening);
    }
    if (closing) {
      const matchingIndex = environments.lastIndexOf(closing);
      if (matchingIndex >= 0) environments.splice(matchingIndex, 1);
    }
  }

  flushParagraph();
  while (output.at(-1) === "") output.pop();
  return `${output.join("\n")}\n`;
}

function wrapWords(words: string[], indentation: number, lineWidth: number): string[] {
  const prefix = "  ".repeat(indentation);
  const continuationPrefix = `${prefix}  `;
  const width = Math.max(lineWidth, prefix.length + 20);
  const lines: string[] = [];
  let current = prefix;
  let currentPrefix = prefix;

  for (const word of words) {
    const separator = current === currentPrefix ? "" : " ";
    if (
      current.length > currentPrefix.length &&
      current.length + separator.length + word.length > width
    ) {
      lines.push(current);
      currentPrefix = continuationPrefix;
      current = `${currentPrefix}${word}`;
    } else {
      current += `${separator}${word}`;
    }
  }
  if (current.length > currentPrefix.length) lines.push(current);
  return lines;
}

function snippet(
  label: string,
  detail: string,
  insertText: string,
  description = `Inserts the ${detail.toLowerCase()} syntax.`,
): CompletionItem {
  const example = snippetExample(insertText);
  return {
    label,
    detail,
    documentation: documentation(detail, description, example),
    insertText,
    signature: example.split("\n")[0] ?? label,
  };
}

function environment(name: string, detail: string, body = "$0"): CompletionItem {
  const insertion = `${name}}\n\t${body}\n\\end{${name}}`;
  const example = `\\begin{${snippetExample(insertion)}`;
  return {
    label: name,
    detail,
    documentation: documentation(
      detail,
      `Creates a matched ${name} environment and places the cursor inside it.`,
      example,
    ),
    insertText: insertion,
    signature: example.split("\n")[0] ?? name,
  };
}

function value(
  label: string,
  detail: string,
  insertText: string,
  description: string,
  example: string,
): CompletionItem {
  return {
    label,
    detail,
    documentation: documentation(detail, description, example),
    insertText,
    signature: example,
  };
}

function snippetExample(insertText: string): string {
  return insertText.replace(/\$\{\d+:([^}]*)}/g, "$1").replace(/\$\d+/g, "content");
}

function documentation(title: string, description: string, example: string): string {
  return `**${title}**\n\n${description}\n\n\`\`\`latex\n${example}\n\`\`\``;
}

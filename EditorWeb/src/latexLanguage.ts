export interface CompletionItem {
  label: string;
  detail: string;
  documentation: string;
  insertText: string;
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
  snippet("\\section", "Section", "\\section{${1:title}}"),
  snippet("\\section*", "Unnumbered section", "\\section*{${1:title}}"),
  snippet("\\subsection", "Subsection", "\\subsection{${1:title}}"),
  snippet("\\subsubsection", "Subsubsection", "\\subsubsection{${1:title}}"),
  snippet("\\documentclass", "Document class", "\\documentclass[${1:options}]{${2:article}}"),
  snippet("\\usepackage", "Package import", "\\usepackage[${1:options}]{${2:package}}"),
  snippet("\\begin", "Environment", "\\begin{${1:environment}}\n\t$0\n\\end{${1:environment}}"),
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

export function completionItems(prefix: string): CompletionItem[] {
  if (!prefix.startsWith("\\")) return [];
  return completions.filter((item) => item.label.startsWith(prefix));
}

export function formatLaTeX(source: string): string {
  const lines = source.split(/\r?\n/);
  const output: string[] = [];
  let indentation = 0;

  for (const originalLine of lines) {
    const line = originalLine.trimEnd().trimStart();
    if (line.length === 0) {
      if (output.length > 0 && output.at(-1) !== "") output.push("");
      continue;
    }

    const closing = line.match(/^\\end\{([^}]+)\}/)?.[1];
    if (closing && closing !== "document") indentation = Math.max(0, indentation - 1);

    output.push(`${"  ".repeat(indentation)}${line}`);

    const opening = line.match(/^\\begin\{([^}]+)\}/)?.[1];
    if (
      opening &&
      opening !== "document" &&
      !line.includes(`\\end{${opening}}`)
    ) {
      indentation += 1;
    }
  }

  while (output.at(-1) === "") output.pop();
  return `${output.join("\n")}\n`;
}

function snippet(label: string, detail: string, insertText: string): CompletionItem {
  return {
    label,
    detail,
    documentation: `${detail} snippet`,
    insertText,
  };
}

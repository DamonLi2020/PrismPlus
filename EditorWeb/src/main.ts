import * as monaco from "monaco-editor/editor/editor.api.js";
import EditorWorker from "monaco-editor/editor/editor.worker.js?worker&inline";
import "monaco-editor/editor/contrib/format/browser/formatActions.js";
import "monaco-editor/editor/contrib/suggest/browser/suggestController.js";
import {
  autoClosingPairs,
  completionContext,
  completionItemsForContext,
  formatLaTeX,
  shouldDeferCompilation,
  shouldTriggerSuggestions,
  sourcePositionAfterChange,
} from "./latexLanguage";
import "./style.css";

type BridgeWindow = Window & {
  prismPlus?: {
    focus: () => void;
    format: () => void;
    setSource: (source: string) => void;
  };
  webkit?: {
    messageHandlers?: Record<string, { postMessage: (value: unknown) => void }>;
  };
};

(self as unknown as { MonacoEnvironment: monaco.Environment }).MonacoEnvironment = {
  getWorker: () => new EditorWorker(),
};

monaco.languages.register({ id: "latex", extensions: [".tex", ".ltx"] });
monaco.languages.setLanguageConfiguration("latex", {
  comments: { lineComment: "%" },
  brackets: [
    ["{", "}"],
    ["[", "]"],
    ["(", ")"],
  ],
  autoClosingPairs,
  surroundingPairs: autoClosingPairs,
  indentationRules: {
    increaseIndentPattern: /\\begin\{(?!document)([^}]*)\}(?!.*\\end\{\1\})/,
    decreaseIndentPattern: /^\s*\\end\{(?!document)/,
  },
  autoCloseBefore: ";:.,={}])>` \n\t$",
});

monaco.languages.setMonarchTokensProvider("latex", {
  tokenizer: {
    root: [
      [/%.*$/, "comment"],
      [/\\(?:begin|end)(?=\{)/, "keyword.control"],
      [/\\(?:documentclass|usepackage|title|author|date|maketitle)\*?/, "keyword"],
      [/\\(?:sub)*section\*?/, "type.identifier"],
      [/\\(?:cite|ref|label|pageref)\*?/, "variable.predefined"],
      [/\\[A-Za-z@]+\*?/, "keyword"],
      [/\$\$?|\\\[|\\\]|\\\(|\\\)/, "string"],
      [/[{}[\]()]/, "delimiter.bracket"],
      [/&|\\\\/, "operator"],
    ],
  },
});

monaco.editor.defineTheme("prism-plus", {
  base: "vs-dark",
  inherit: true,
  rules: [
    { token: "comment", foreground: "7F8797", fontStyle: "italic" },
    { token: "keyword", foreground: "65D6C2" },
    { token: "keyword.control", foreground: "5EC7F8", fontStyle: "bold" },
    { token: "type.identifier", foreground: "86B9FF" },
    { token: "variable.predefined", foreground: "C89BFF" },
    { token: "string", foreground: "D9A7FF" },
    { token: "delimiter.bracket", foreground: "F0C86E" },
    { token: "operator", foreground: "EF8C8C" },
  ],
  colors: {
    "editor.background": "#0E1119",
    "editor.foreground": "#DCE1EA",
    "editorLineNumber.foreground": "#626B7A",
    "editorLineNumber.activeForeground": "#C6CEDA",
    "editor.selectionBackground": "#244A73",
    "editorSuggestWidget.background": "#1A1F2A",
    "editorSuggestWidget.border": "#3A4354",
    "editorSuggestWidget.selectedBackground": "#244A73",
  },
});

const editor = monaco.editor.create(document.getElementById("editor")!, {
  value: "",
  language: "latex",
  theme: "prism-plus",
  automaticLayout: true,
  fontFamily: "SFMono-Regular, Menlo, Monaco, monospace",
  fontSize: 15,
  lineHeight: 23,
  fontLigatures: true,
  minimap: { enabled: false },
  padding: { top: 12, bottom: 16 },
  scrollBeyondLastLine: false,
  smoothScrolling: true,
  cursorSmoothCaretAnimation: "on",
  bracketPairColorization: { enabled: true },
  guides: { bracketPairs: true, indentation: true },
  autoClosingBrackets: "always",
  autoClosingQuotes: "always",
  autoIndent: "full",
  formatOnPaste: true,
  quickSuggestions: { other: true, comments: false, strings: true },
  suggestOnTriggerCharacters: true,
  snippetSuggestions: "top",
  wordBasedSuggestions: "off",
  tabCompletion: "on",
  tabSize: 2,
  insertSpaces: true,
  acceptSuggestionOnEnter: "on",
  suggest: {
    preview: true,
    showIcons: true,
    showInlineDetails: true,
    showStatusBar: true,
  },
});

monaco.languages.registerCompletionItemProvider("latex", {
  triggerCharacters: ["\\", "{"],
  provideCompletionItems(model, position) {
    const line = model.getLineContent(position.lineNumber);
    const lineBeforeCursor = line.slice(0, position.column - 1);
    const lineAfterCursor = line.slice(position.column - 1);
    const context = completionContext(lineBeforeCursor, lineAfterCursor);
    if (!context) return { suggestions: [] };
    const range = new monaco.Range(
      position.lineNumber,
      position.column - context.prefix.length,
      position.lineNumber,
      position.column + context.consumeAfterCursor,
    );
    return {
      suggestions: completionItemsForContext(context).map((item) => ({
        label: item.label,
        detail: `${item.detail} — ${item.signature}`,
        documentation: { value: item.documentation, isTrusted: false },
        insertText: item.insertText,
        insertTextRules: monaco.languages.CompletionItemInsertTextRule.InsertAsSnippet,
        kind: monaco.languages.CompletionItemKind.Snippet,
        range,
      })),
    };
  },
});

function showSuggestions(): void {
  void editor.getAction("editor.action.triggerSuggest")?.run().then(() => {
    window.setTimeout(() => {
      if (document.querySelector(".suggest-details-container")) return;
      editor.trigger("prism-plus", "toggleSuggestionDetails", null);
    }, 100);
  });
}

editor.addCommand(monaco.KeyMod.WinCtrl | monaco.KeyCode.Space, showSuggestions);

editor.onDidType((typedText) => {
  const position = editor.getPosition();
  const model = editor.getModel();
  if (!position || !model) return;
  const lineBeforeCursor = model
    .getLineContent(position.lineNumber)
    .slice(0, position.column - 1);
  if (!shouldTriggerSuggestions(lineBeforeCursor, typedText)) return;

  requestAnimationFrame(showSuggestions);
});

monaco.languages.registerDocumentFormattingEditProvider("latex", {
  provideDocumentFormattingEdits(model) {
    return [{ range: model.getFullModelRange(), text: formatLaTeX(model.getValue()) }];
  },
});

let applyingNativeUpdate = false;
const bridgeWindow = window as BridgeWindow;
editor.onDidChangeModelContent((event) => {
  if (applyingNativeUpdate) return;
  const model = editor.getModel();
  const lastChange = event.changes.at(-1);
  let deferAutomaticCompilation = false;
  if (model && lastChange) {
    const position = sourcePositionAfterChange(
      lastChange.range.startLineNumber,
      lastChange.range.startColumn,
      lastChange.text,
    );
    const line = model.getLineContent(position.lineNumber);
    deferAutomaticCompilation = shouldDeferCompilation(
      line.slice(0, position.column - 1),
      line.slice(position.column - 1),
    );
  }
  bridgeWindow.webkit?.messageHandlers?.sourceChanged?.postMessage({
    source: editor.getValue(),
    deferAutomaticCompilation,
  });
});

bridgeWindow.prismPlus = {
  focus: () => editor.focus(),
  format: () => editor.getAction("editor.action.formatDocument")?.run(),
  setSource(source: string) {
    if (editor.getValue() === source) return;
    const viewState = editor.saveViewState();
    applyingNativeUpdate = true;
    editor.setValue(source);
    if (viewState) editor.restoreViewState(viewState);
    applyingNativeUpdate = false;
  },
};

bridgeWindow.webkit?.messageHandlers?.editorReady?.postMessage(true);

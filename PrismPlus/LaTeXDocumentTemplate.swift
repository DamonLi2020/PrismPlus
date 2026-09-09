import Foundation

enum LaTeXDocumentTemplate {
    static let standard = #"""
        \documentclass[11pt]{article}

        % Essential packages
        \usepackage[margin=1in]{geometry}
        \usepackage{amsmath,amssymb}

        \title{Your Document Title}
        \author{Damon Li}
        \date{\today}

        \begin{document}
        \maketitle

        \section{Introduction}
        Start writing here.

        \end{document}
        """#
}

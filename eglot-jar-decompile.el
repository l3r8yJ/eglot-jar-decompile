;;; eglot-jar-decompile.el --- Jump to jar sources and decompiled classes -*- lexical-binding: t; -*-

;; Author: Ivan Ivanchuk
;; URL: https://github.com/l3r8yJ/eglot-jar-decompile
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, languages
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Resolve jar: URIs returned by Eglot and lsp-mode into real source
;; files, extracting sources jars or decompiling class files.

;;; Code:

(require 'xref)

(defgroup eglot-jar-decompile nil
  "Resolve jar: URIs into readable sources."
  :group 'tools
  :prefix "eglot-jar-decompile-")

(defcustom eglot-jar-decompile-cache-directory
  (expand-file-name
   "eglot-jar-decompile/"
   (or (getenv "XDG_CACHE_HOME") "~/.cache"))
  "Directory for extracted and decompiled files."
  :type 'directory)

(define-minor-mode eglot-jar-decompile-mode
  "Resolve jar: URIs from Eglot and lsp-mode."
  :global t
  :group 'eglot-jar-decompile)

(provide 'eglot-jar-decompile)
;;; eglot-jar-decompile.el ends here

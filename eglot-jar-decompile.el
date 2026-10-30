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
(require 'url-parse)

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

(defun eglot-jar-decompile--parse-uri (uri)
  "Parse URI into a (:jar PATH :entry ENTRY) plist, or nil when not a jar URI."
  (when (and (stringp uri) (string-prefix-p "jar:" uri))
    (let* ((body (substring uri 4))
           (body (if (string-prefix-p "file://" body)
                     (substring body 7)
                   body))
           (sep (string-search "!/" body)))
      (unless sep
        (user-error "Malformed jar URI: %s" uri))
      (let ((jar (substring body 0 sep))
            (entry (substring body (+ sep 2))))
        (when (string-search "!/" entry)
          (user-error "Nested jar archives are not supported: %s" uri))
        (when (string-prefix-p "//" jar)
          (setq jar (substring jar 2)))
        (list :jar (url-unhex-string jar)
              :entry (url-unhex-string entry))))))

(provide 'eglot-jar-decompile)
;;; eglot-jar-decompile.el ends here

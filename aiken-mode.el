;;; aiken-mode.el --- Major mode for Aiken -*- lexical-binding: t -*-

;; Copyright © 2023 Sebastian Nagel <sebastian.nagel@ncoding.at>

;; Author: Sebastian Nagel <sebastian.nagel@ncoding.at>
;; URL: https://github.com/aiken-lang/aiken-mode
;; Keywords: languages aiken
;; Version: 1.0.2
;; Package-Requires: ((emacs "26.1"))
;; SPDX-License-Identifier: MPL-2.0

;; This file is NOT part of GNU Emacs.

;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at http://mozilla.org/MPL/2.0/.

;;; Commentary:

;; Provides syntax highlighting for the Aiken smart contract language.

;;; Code:

;; Aiken syntax

(defvar aiken-keywords
  '("if"
    "else"
    "when"
    "is"
    "fn"
    "use"
    "let"
    "pub"
    "type"
    "opaque"
    "const"
    "todo"
    "error"
    "expect"
    "test"
    "trace"
    "fail"
    "validator"
    "and"
    "or"))

(defvar aiken-operators
  '(
    "="
    "->"
    ".."
    "|>"
    ">="
    "<="
    ">"
    "<"
    "!="
    "=="
    "&&"
    "||"
    "!"
    "+"
    "-"
    "/"
    "*"
    "%"
    "?"))

(defvar aiken-font-lock-keywords
  (append
   `(
     ;; Keywords
     (,(regexp-opt aiken-keywords 'symbols) . font-lock-keyword-face)
     ;; CamelCase is a type
     ("[[:upper:]][[:word:]]*" . font-lock-type-face)
     ;; Operators
     (,(regexp-opt aiken-operators nil) . font-lock-builtin-face))
   ;; Identifiers after keywords
   (mapcar (lambda (x)
             (list (concat (car x) "[^(]\\(\\w*\\)")
                   1 ;; apply face ot first match group
                   (cdr x)))
           '(("const" . font-lock-type-face)
             ("type" . font-lock-type-face)
             ("use" . font-lock-constant-face)
             ("fn" . font-lock-function-name-face)))))

;; Mode definitions

;;;###autoload
(define-derived-mode aiken-mode prog-mode "aiken"
  "Major mode for Aiken code."
  :group 'aiken-mode

  (setq-local indent-tabs-mode nil)

  ;; Syntax highlighting via font-lock
  (setq-local font-lock-defaults '(aiken-font-lock-keywords))

  ;; Syntax: make _ part of words
  (modify-syntax-entry ?_ "w" aiken-mode-syntax-table)

  ;; Comment syntax
  (modify-syntax-entry ?/ ". 124b" aiken-mode-syntax-table)
  (modify-syntax-entry ?\n "> b" aiken-mode-syntax-table)
  (modify-syntax-entry ?\^m "> b" aiken-mode-syntax-table)

  ;; Comment settings
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+ *")
  (setq-local comment-use-syntax t)
  (setq-local comment-auto-fill-only-comments t)
  (setq-local tab-width 2)
  (setq-local indent-line-function 'my-indent-line))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ak\\'" . aiken-mode))

(require 'lsp-mode)
;;
;; aiken-lsp starts here
;;
;; ---------------------------------------------------------------------
;; Configuration

(require 'flycheck)

(defgroup aiken-lsp nil
  "Customization group for ‘aiken-lsp’."
  :group 'lsp-mode)

;;
;; helper functions
;;
;; we assume the `aiken' binary is in the $PATH
(defcustom aiken-lsp-server-path
  "aiken"
  "The language server executable.
Can be something on the $PATH (e.g. `aiken') or a path to an executable itself."
  :group 'aiken-lsp
  :type 'string)

;; As of aiken v1.0.26, no args are required. However this might change in future version of aiken
(defcustom aiken-lsp-server-args
  `("--stdio")
  "The arguments for starting the language server."

  :group 'aiken-lsp
  :type '(repeat (string :tag "Argument")))

;; As of aiken v1.0.26, no wrapper is required.
(defcustom aiken-lsp-server-wrapper-function
  #'identity
  "Use this wrapp the lsp server process."
  :group 'aiken-lsp
  :type '(choice
          (function-item :tag "None" :value identity)
          (function :tag "Custom function")))

(defun aiken-lsp--server-command ()
  "Command and arguments for launching the inferior language server process.
These are assembled from the customizable variables `aiken-lsp-server-path'
and `aiken-lsp-server-args' and `aiken-lsp-server-wrapper-function'."
  (funcall aiken-lsp-server-wrapper-function (append (list aiken-lsp-server-path "lsp") aiken-lsp-server-args) ))

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection (lambda () (aiken-lsp--server-command)))
  ;; should run under aiken-mode
  :major-modes '(aiken-mode)
  :server-id 'aiken-lsp
  :activation-fn (lsp-activate-on "aiken")
  ;; :initialized-fn (lambda (workspace) (with-lsp-workspace workspace (lsp--set-configuration (lsp-configuration-section "aiken"))))
  :synchronize-sections '("aiken")
  :language-id "aiken"))

(add-to-list 'lsp-language-id-configuration '(aiken-mode . "aiken"))

(defun aiken-format-buffer ()
  "Format the current buffer with aiken fmt."
  (interactive)
  (let ((mi-buffer (get-buffer-create "*Error*"))
	(patch-buffer (get-buffer-create "*AikenFmt Patch*"))
	(buffer-original (current-buffer))
        (args '("fmt" "--stdin"))
        (current-point (point)))
    (unwind-protect
        (let* ((exit-code
                (apply 'call-process-region (point-min) (point-max) "aiken" nil (list patch-buffer t) nil args))
               (error-message (with-current-buffer patch-buffer
                                (buffer-string))))
          (if (zerop exit-code)
              (progn
                (erase-buffer)
                (insert-buffer-substring patch-buffer)
                (goto-char current-point)
                (message "Buffer formatted with aiken fmt"))
            (message "aiken fmt failed: see *AikenFmt Patch* buffer for details")
            ;; Mostrar el buffer de errores en caso de falla
            ;;(display-buffer patch-buffer)
	    ;;(with-current-buffer patch-buffer
	      ;;(insert "Content of patch-buffer: \n%s" error-message))
	    ;;(display-buffer patch-buffer)))
	    (with-current-buffer mi-buffer
	      (insert error-message)
	      (read-only-mode 1)
	      (local-set-key (kbd "q")
                     (lambda ()
                       (interactive)
                       (kill-buffer mi-buffer)
                       (switch-to-buffer buffer-original)
                       (delete-other-windows))))
	    (display-buffer mi-buffer)))
;;	    (display-buffer mi-buffer)))
      ;; Asegúrate de que el buffer de errores se mata después de su uso
      (when (buffer-live-p patch-buffer)
        (kill-buffer patch-buffer)))))



(add-hook 'aiken-mode-hook #'lsp)

(defun first-non-whitespace-char-is-close-brace? ()
  "Check if the first non-whitespace character in the current line is a closing brace (`}`)."
  (save-excursion
    (beginning-of-line)
    ;; Moverse al primer carácter no blanco
    (skip-syntax-forward " ")
    ;; Verificar si el primer carácter no blanco es una llave de cierre
    (looking-at "}")))


(defun my-indent-line ()
  "Indent the current line based on the number of nested braces.
If the first token of the line is a closing brace, reduce the indentation level."
  (interactive)
  (let ((indent-level 0)
        (pos (point))
        (start-of-line (line-beginning-position))
        (first-char nil))
    (save-excursion
      ;; Mover al inicio de la línea
      (goto-char start-of-line)
      (setq first-char (char-to-string (char-after)))
      ;; Contar llaves abiertas y cerradas hasta el punto actual
      (goto-char (point-min))
      (while (< (point) start-of-line)
        (when (looking-at "{")
          (setq indent-level (+ indent-level 1)))
        (when (looking-at "}")
          (setq indent-level (max 0 (- indent-level 1))))
        (forward-char 1))
      ;; Ajustar indentación si la primera posición de la línea es una llave de cierre
      (if (first-non-whitespace-char-is-close-brace?)
          (setq indent-level (max 0 (- indent-level 1))))
      ;; Aplicar la indentación según el nivel de anidación de las llaves
      (indent-line-to (* indent-level 2)))))


(provide 'aiken-mode)
;;; aiken-mode.el ends here

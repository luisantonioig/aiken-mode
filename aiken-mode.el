;; aiken-mode.el -- Modo para editar archivos de Aiken

(defvar aiken-mode-hook nil)
(defvar aiken-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for Aiken major mode")

;; Definir palabras clave para el resaltado
(defconst aiken-font-lock-keywords
  (list
   ;; Comentarios de línea
   '("//.*$" . font-lock-comment-face)
   
   ;; Importaciones con desestructuración
   '("\\<use\\>\\s-+\\([[:alnum:]_/]+\\)\\.{\\([^}]*\\)}" 
     (1 font-lock-string-face)
     (2 font-lock-type-face))
   
   ;; Importaciones simples
   '("\\<use\\>\\s-+\\([[:alnum:]_/]+\\)\\($\\|[^.]\\)" 1 font-lock-string-face)
   
   ;; Definiciones de funciones y validadores
   '("\\<\\(fn\\|validator\\)\\>\\s-+\\([[:alpha:]][[:alnum:]_]*\\)" 2 font-lock-function-name-face)
   
   ;; Variables declaradas con let
   '("\\<let\\>\\s-+\\([[:alpha:]][[:alnum:]_]*\\)" 1 font-lock-variable-name-face)
   
   ;; Palabras clave del lenguaje
   '("\\<\\(use\\|fn\\|pub\\|const\\|type\\|let\\|if\\|else\\|when\\|is\\|and\\|or\\|todo\\|trace\\|expect\\|test\\|validator\\)\\>" . font-lock-keyword-face)
   
   ;; Tipos
   '("\\<\\(Bool\\|Int\\|ByteArray\\|String\\|List\\|Option\\|Void\\|Data\\)\\>" . font-lock-type-face)
   
   ;; Constructores y valores
   '("\\<\\(True\\|False\\|None\\|Some\\)\\>" . font-lock-constant-face)
   
   ;; Funciones built-in
   '("\\<\\(error\\|trace\\|concat\\|slice\\|length\\|verify\\|assert\\)\\>" . font-lock-builtin-face)
   
   ;; Operadores
   '("\\(->[[:space:]]\\|=>\\|[?]\\|[:]\\|==\\|!=\\|\\.\\|<\\|>\\|<=\\|>=\\|=\\|+\\|-\\|*\\|/\\|%\\)" . font-lock-function-name-face)
   
   ;; Números (varios formatos)
   '("\\b0b[0-1]+\\b" . font-lock-constant-face)
   '("\\b0o[0-7]+\\b" . font-lock-constant-face)
   '("\\b0x[[:xdigit:]]+\\b" . font-lock-constant-face)
   '("\\b[[:digit:]][[:digit:]_]*(\\.[[:digit:]]*)?\\b" . font-lock-constant-face)
   
   ;; Tipos que comienzan con mayúscula
   '("\\<[[:upper:]][[:word:]]*\\>" . font-lock-type-face)
   
   ;; Llamadas a funciones (identificador seguido de paréntesis)
   '("\\b\\([[:alpha:]][[:alnum:]_]*\\)\\s-*(" 1 font-lock-function-name-face)
   
   ;; Parámetros (capturando desde los dos puntos)
   '("\\([^:,\n\r (){}]*\\):" 1 font-lock-variable-name-face)
   
   ;; Cadenas de texto 
   '("\".*?\"" . font-lock-string-face)
   ;; NOTE @luisantonioig: Still does not highligth identifiers in expressions
   ;; NOTE @luisantonioig: Maybe it does not have to
   ;; Variables (identificadores en expresiones)
   '("\\<\\([[:alpha:]][[:alnum:]_]*\\)\\>" 1 font-lock-variable-face))
  "Resaltado de sintaxis para Aiken mode")

(defun aiken-indent-line ()
  "Indent current line as Aiken code."
  (interactive)
  (let ((savep (> (current-column) (current-indentation)))
        (indent 0))
    
    (save-excursion
      (beginning-of-line)
      (if (bobp) ; Primera línea del archivo
          (setq indent 0)
        (let ((closes-block (looking-at "\\s-*\\(}\\|\\]\\|)\\|end\\)")))
          ;; Encontrar indentación base
          (if closes-block
              (progn
                ;; Si cierra un bloque, buscar la apertura correspondiente
                (beginning-of-line)
                (skip-chars-forward " \t")
                (backward-up-list 1)
                (setq indent (current-indentation)))
            ;; Usar indentación de línea anterior
            (forward-line -1)
            (setq indent (current-indentation))
            ;; Si la línea anterior abre un bloque, añadir indentación
            (end-of-line)
            (skip-chars-backward " \t")
            (backward-char)
            (when (looking-at "[{(\\[]")
              (setq indent (+ indent 2)))))))
    
    ;; Aplicar indentación
    (save-excursion
      (beginning-of-line)
      (delete-horizontal-space)
      (indent-to indent))
    
    ;; Restaurar posición del cursor
    (when savep
      (move-to-column (+ indent (- (current-column) (current-indentation)))))))

(defun aiken-new-line-and-indent ()
  "insert a new line and indent."
  (interactive)
  (newline)
  (aiken-indent-line)
  (end-of-line))

(define-derived-mode aiken-mode prog-mode "Aiken"
  "Modo mayor para editar archivos de Aiken"
  (setq font-lock-defaults '(aiken-font-lock-keywords))
  (setq-local comment-start "//")
  (setq-local comment-end "")
  
  ;; Indentación personalizada en lugar de SMIE
  (setq-local indent-line-function 'aiken-indent-line)
  
  ;; Otras opciones útiles
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 2)
  (setq-local show-paren-mode t)

  (local-set-key (kbd "RET") 'aiken-new-line-and-indent)
  
  (run-hooks 'aiken-mode-hook))


;; Asociar archivos .ak con aiken-mode
(add-to-list 'auto-mode-alist '("\\.ak\\'" . aiken-mode))

;; (require 'lsp-mode)

;; ;; Definición simplificada del cliente
;; (lsp-register-client
;;  (make-lsp-client
;;   :new-connection (lsp-stdio-connection
;;                    (lambda ();
;;                      (list "aiken" "lsp" "--stdio")))
;;   :major-modes '(aiken-mode)
;;   :server-id 'aiken-ls))

;; ;; Creación del modo si no existe
;; (unless (fboundp 'aiken-mode)
;;   (define-derived-mode aiken-mode prog-mode "Aiken"
;;     "Major mode for editing Aiken files."
;;     (setq-local comment-start "--")
;;     (setq-local comment-end "")))

;; ;; Asociar extensiones de archivo
;; (add-to-list 'auto-mode-alist '("\\.ak\\'" . aiken-mode))

;; ;; TODO @luisantonioig: Probably I need to put this part outside of the mode
;; ;; Activar LSP al abrir archivos Aiken
;; (add-hook 'aiken-mode-hook #'lsp)

;; (add-to-list 'lsp-language-id-configuration '(aiken-mode . "aiken"))

(provide 'aiken-mode)

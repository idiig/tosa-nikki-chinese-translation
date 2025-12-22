#!/usr/bin/env guile
!#

(use-modules (ice-9 textual-ports)
             (ice-9 regex)
             (json))

;; Set UTF-8 encoding for input/output
(set-port-encoding! (current-input-port) "UTF-8")
(set-port-encoding! (current-output-port) "UTF-8")
(set-port-encoding! (current-error-port) "UTF-8")

;;; ==================================================================
;;; Hiragana to Romaji conversion (Nihon-shiki)
;;; ==================================================================

(define hiragana-romaji-table
  '(("あ" . "a") ("い" . "i") ("う" . "u") ("え" . "e") ("お" . "o")
    ("か" . "ka") ("き" . "ki") ("く" . "ku") ("け" . "ke") ("こ" . "ko")
    ("が" . "ga") ("ぎ" . "gi") ("ぐ" . "gu") ("げ" . "ge") ("ご" . "go")
    ("さ" . "sa") ("し" . "si") ("す" . "su") ("せ" . "se") ("そ" . "so")
    ("ざ" . "za") ("じ" . "zi") ("ず" . "zu") ("ぜ" . "ze") ("ぞ" . "zo")
    ("た" . "ta") ("ち" . "ti") ("つ" . "tu") ("て" . "te") ("と" . "to")
    ("だ" . "da") ("ぢ" . "di") ("づ" . "du") ("で" . "de") ("ど" . "do")
    ("な" . "na") ("に" . "ni") ("ぬ" . "nu") ("ね" . "ne") ("の" . "no")
    ("は" . "ha") ("ひ" . "hi") ("ふ" . "hu") ("へ" . "he") ("ほ" . "ho")
    ("ば" . "ba") ("び" . "bi") ("ぶ" . "bu") ("べ" . "be") ("ぼ" . "bo")
    ("ぱ" . "pa") ("ぴ" . "pi") ("ぷ" . "pu") ("ぺ" . "pe") ("ぽ" . "po")
    ("ま" . "ma") ("み" . "mi") ("む" . "mu") ("め" . "me") ("も" . "mo")
    ("や" . "ya") ("ゆ" . "yu") ("よ" . "yo")
    ("ら" . "ra") ("り" . "ri") ("る" . "ru") ("れ" . "re") ("ろ" . "ro")
    ("わ" . "wa") ("ゐ" . "wi") ("ゑ" . "we") ("を" . "wo") ("ん" . "n")
    ;; Youon (拗音)
    ("きゃ" . "kya") ("きゅ" . "kyu") ("きょ" . "kyo")
    ("ぎゃ" . "gya") ("ぎゅ" . "gyu") ("ぎょ" . "gyo")
    ("しゃ" . "sya") ("しゅ" . "syu") ("しょ" . "syo")
    ("じゃ" . "zya") ("じゅ" . "zyu") ("じょ" . "zyo")
    ("ちゃ" . "tya") ("ちゅ" . "tyu") ("ちょ" . "tyo")
    ("ぢゃ" . "dya") ("ぢゅ" . "dyu") ("ぢょ" . "dyo")
    ("にゃ" . "nya") ("にゅ" . "nyu") ("にょ" . "nyo")
    ("ひゃ" . "hya") ("ひゅ" . "hyu") ("ひょ" . "hyo")
    ("びゃ" . "bya") ("びゅ" . "byu") ("びょ" . "byo")
    ("ぴゃ" . "pya") ("ぴゅ" . "pyu") ("ぴょ" . "pyo")
    ("みゃ" . "mya") ("みゅ" . "myu") ("みょ" . "myo")
    ("りゃ" . "rya") ("りゅ" . "ryu") ("りょ" . "ryo")
    ;; Small tsu (促音)
    ("っ" . "'")))

(define (hiragana->romaji str)
  "Convert hiragana string to romaji using Nihon-shiki romanization"
  (let loop ((chars (string->list str))
             (result ""))
    (if (null? chars)
        result
        (let* ((c1 (string (car chars)))
               (c2 (if (null? (cdr chars)) "" (string (cadr chars))))
               (two-char (string-append c1 c2))
               (two-char-match (and (not (string=? two-char ""))
                                   (not (null? (cdr chars)))
                                   (assoc-ref hiragana-romaji-table two-char)))
               (one-char-match (assoc-ref hiragana-romaji-table c1)))
          (cond
           (two-char-match
            ;; Matched two characters
            (loop (cddr chars) (string-append result two-char-match)))
           (one-char-match
            ;; Matched one character
            (loop (cdr chars) (string-append result one-char-match)))
           (else
            ;; No match, keep original character
            (loop (cdr chars) (string-append result c1))))))))

(define (insert-hyphen-before-last-char str)
  "Insert hyphen before the last character in a string"
  (if (< (string-length str) 2)
      str
      (let ((len (string-length str)))
        (string-append (substring str 0 (- len 1))
                       "-"
                       (substring str (- len 1))))))

(define (romanize-if-needed word gloss-morph-zh)
  "Romanize word if gloss-morph-zh starts with 汉字-TAG pattern"
  ;; Check if gloss-morph-zh contains a pattern like "做-ADV" or "说-ADN"
  ;; This means: Chinese character(s) followed by hyphen and uppercase letters
  (let ((needs-romanization 
         (and (> (string-length gloss-morph-zh) 0)
              ;; Match patterns like: 做-CCL, 试-ADV, 说-ADN
              ;; But not: =IFO, =CMP, 男人, 日记
              (string-match "^[^-=+A-Za-z]+[-][A-Z]" gloss-morph-zh))))
    (if needs-romanization
        (insert-hyphen-before-last-char (hiragana->romaji word))
        word)))

;;; ==================================================================
;;; Convert uppercase tags to \sc{lowercase}
;;; ==================================================================

(define (convert-tags str)
  "Convert uppercase letter sequences to \\sc{lowercase} format"
  (regexp-substitute/global
   #f "([A-Z]+)"
   str
   'pre
   (lambda (m)
     (string-append "\\sc{" (string-downcase (match:substring m 1)) "}"))
   'post))

;;; ==================================================================
;;; Escape TeX special characters
;;; ==================================================================

(define (escape-tex str)
  "Escape special TeX characters"
  (let* ((str (regexp-substitute/global #f "\\\\" str 'pre "\\textbackslash{}" 'post))
         (str (regexp-substitute/global #f "([#$%&_{}])" str 'pre "\\\\\\1" 'post))
         (str (regexp-substitute/global #f "~" str 'pre "\\textasciitilde{}" 'post))
         (str (regexp-substitute/global #f "\\^" str 'pre "\\textasciicircum{}" 'post)))
    str))

;;; ==================================================================
;;; Generate margintable for glossary abbreviations
;;; ==================================================================

(define (generate-margintable glossary-list)
  "Generate margintable with glossary abbreviations"
  (string-append
   "\\begin{margintable}\n"
   "\\caption{符号一览表（1）}\n"
   "\\small\n"
   "\\begin{tabular}{rl}\n"
   "\\toprule\n"
   "\\bfseries 符号 & \\bfseries 语法功能\\\\\\midrule\n"
   (string-join
    (map (lambda (entry)
           (let ((gloss (assoc-ref entry "gloss"))
                 (func-en (assoc-ref entry "grammatical_function_en")))
             (string-append 
              (if (string=? gloss "+") "+" 
                  (if (string=? gloss "-") "-"
                      (if (string=? gloss "=") "="
                          (string-append "\\sc{" (string-downcase gloss) "}"))))
              ": & "
              func-en
              "\\\\")))
         glossary-list)
    "\n")
   "\\bottomrule\n"
   "\\end{tabular}\n"
   "\\end{margintable}\n\n"))

;;; ==================================================================
;;; Generate \begingl blocks for phrase glosses
;;; ==================================================================

(define (generate-gloss phrase-gloss)
  "Generate a \\begingl block for one phrase gloss"
  (let* ((phrase (assoc-ref phrase-gloss "phrase"))
         (gloss-zh (assoc-ref phrase-gloss "gloss-zh"))
         (words (vector->list (assoc-ref phrase-gloss "words")))
         (word-lines 
          (map (lambda (word-entry)
                 (let ((word (assoc-ref word-entry "word"))
                       (gloss-zh (assoc-ref word-entry "gloss-zh"))
                       (gloss-morph-zh (assoc-ref word-entry "gloss-morph-zh")))
                   (string-append
                    (romanize-if-needed word gloss-morph-zh)
                    "["
                    (escape-tex gloss-morph-zh)
                    "/"
                    (convert-tags (escape-tex gloss-morph-zh))
                    "/"
                    (if (string=? gloss-morph-zh "") "" "/")
                    (escape-tex gloss-zh)
                    "]")))
               words)))
    (string-append
     "\\a\n"
     "\\begingl[glstyle=nlevel,glneveryline={\\it,\\it\\footnotesize,\\sc\\footnotesize,\\bfseries\\footnotesize},\n"
     "glnabovelineskip={,-.4ex,-.4ex},extraglskip=0pt,glwordalign=center]\n"
     "\\glpreamble " phrase " \\endpreamble\n"
     (string-join word-lines "\n")
     "\n\\glft `" (escape-tex gloss-zh) "'\n"
     "\\endgl\n")))

;;; ==================================================================
;;; Generate complete TeX output
;;; ==================================================================

(define (generate-tex paragraph-data)
  "Generate complete TeX output from paragraph JSON data"
  (let* ((id (assoc-ref paragraph-data "id"))
         (koutei (assoc-ref paragraph-data "koutei-yamagen"))
         (translation-zh (assoc-ref paragraph-data "translation-zh"))
         (translation-natural (assoc-ref paragraph-data "translation-zh-natural"))
         (phrase-glosses (vector->list (assoc-ref paragraph-data "phrase-gloss")))
         (glossary (vector->list (assoc-ref paragraph-data "glossary-abbreviations")))
         (kana (assoc-ref paragraph-data "kana"))  ; May be #f if not present
         (notes (assoc-ref paragraph-data "notes")) ; May be #f if not present
         (footnote-text
          (if (and notes (> (vector-length notes) 0))
              (string-append
               "\\footnote{%\n"
               (string-join
                (map escape-tex (vector->list notes))
                "\\\\%\n")
               "%\n}")
              "")))
    
    (string-append
     "\\setchapterpreamble[u]{\\margintoc}\n\n"
     (generate-margintable glossary)
     "\\lingset{textanchor=numleft,\n"
     "labelanchor=numleft,\n"
     "labeloffset=.35in,\n"
     "textoffset=.8in}\n\n"
     "\\pex[tag=id" (number->string id) "] "
     koutei
     footnote-text
     "\n"
     ;; Kana version (if present)
     (if kana
         (string-append "\\a[label=\\textbf{\\underline{かな}}] \n"
                       kana "\n")
         "")
     ;; Direct translation
     "\\a[label=\\textbf{\\underline{直译}}] \n"
     translation-zh "\n"
     ;; Natural translation
     "\\a[label=\\textbf{\\underline{意译}}] \n"
     translation-natural "\n"
     "\\a\n"
     ;; Phrase glosses
     (string-join (map generate-gloss phrase-glosses) "")
     "\\xe\n\n"
     "\\newpage\n\n")))

;;; ==================================================================
;;; Main entry point
;;; ==================================================================

(define (main args)
  (if (< (length args) 4)
      (begin
        (display "Usage: guile json-to-tex.scm <input.json> <id> <output.tex>\n" (current-error-port))
        (display "  <input.json> - Input JSON file\n" (current-error-port))
        (display "  <id>         - Paragraph ID to process (or 'all' for all paragraphs)\n" (current-error-port))
        (display "  <output.tex> - Output TeX file\n" (current-error-port))
        (exit 1)))
  
  (let* ((input-file (cadr args))
         (id-arg (caddr args))
         (output-file (cadddr args))
         (json-text (call-with-input-file input-file 
                      (lambda (port)
                        (set-port-encoding! port "UTF-8")
                        (get-string-all port))))
         (json-data (json-string->scm json-text))
         ;; Handle both array and object structures
         (paragraph-data 
          (cond
           ;; Case 1: Top-level array [{"paragraph": [...]}, ...]
           ((vector? json-data)
            (let ((first-item (vector-ref json-data 0)))
              (assoc-ref first-item "paragraph")))
           ;; Case 2: Top-level object {"paragraph": [...]}
           ((list? json-data)
            (assoc-ref json-data "paragraph"))
           (else 
            (begin
              (display "Error: Unexpected JSON structure\n" (current-error-port))
              (exit 1)))))
         (paragraph-list (if (vector? paragraph-data)
                            (vector->list paragraph-data)
                            (list paragraph-data))))
    
    ;; Debug: Show what we found
    (display (format #f "Loaded ~a paragraphs from JSON\n" (length paragraph-list))
            (current-error-port))
    
    ;; Debug: Show IDs
    (for-each (lambda (para)
                (let ((para-id (assoc-ref para "id")))
                  (display (format #f "  Found paragraph with id: ~a~%" para-id)
                          (current-error-port))))
              paragraph-list)
    
    (let* (;; Filter by ID if not "all"
           (filtered-list 
            (if (string=? id-arg "all")
                paragraph-list
                (let ((target-id (string->number id-arg)))
                  (if target-id
                      (filter (lambda (para)
                                (let ((para-id (assoc-ref para "id")))
                                  (cond
                                   ((not para-id)
                                    (display "Warning: Paragraph has no 'id' field, skipping.\n"
                                            (current-error-port))
                                    #f)
                                   ((number? para-id)
                                    (= para-id target-id))
                                   (else
                                    (display (format #f "Warning: Paragraph id '~a' is not a number, skipping.\n" para-id)
                                            (current-error-port))
                                    #f))))
                              paragraph-list)
                      (begin
                        (display (string-append "Error: Invalid ID '" id-arg "'. Must be a number or 'all'.\n")
                                (current-error-port))
                        (exit 1)))))))
      
      ;; Check if we found any paragraphs
      (if (null? filtered-list)
          (begin
            (display (string-append "Error: No paragraph found with ID " id-arg "\n")
                    (current-error-port))
            (exit 1)))
      
      ;; Generate TeX for filtered paragraphs and write to file
      (call-with-output-file output-file
        (lambda (port)
          (set-port-encoding! port "UTF-8")
          (for-each (lambda (para)
                      (display (generate-tex para) port))
                    filtered-list))))))

;; Run main if executed as script
(when (batch-mode?)
  (main (command-line)))

;;; srefactor.el --- A refactoring tool based on Semantic parser framework
;;
;; Filename: srefactor-elisp.el
;; Description: A refactoring tool based on Semantic parser framework
;; Author: Tu, Do Hoang <tuhdo1710@gmail.com>
;; URL      : https://github.com/tuhdo/semantic-refactor
;; Maintainer: Tu, Do Hoang
;; Created: Wed Feb 11 21:25:51 2015 (+0700)
;; Version: 0.3
;; Package-Requires: ((emacs "24.4"))
;; Last-Updated: Wed Feb 11 21:25:51 2015 (+0700)
;;           By: Tu, Do Hoang
;;     Update #: 1
;; URL:
;; Doc URL:
;; Keywords: emacs-lisp, languages, tools
;; Compatibility: GNU Emacs: 24.3+
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;; Semantic is a package that provides a framework for writing
;; parsers. Parsing is a process of analyzing source code based on
;; programming language syntax. This package relies on Semantic for
;; analyzing source code and uses its results to perform smart code
;; refactoring that based on code structure of the analyzed language,
;; instead of plain text structure.
;;
;; This package provides the following features for Emacs Lisp:
;;
;; - `srefactor-elisp-one-line': Transform all sub-sexpressions current sexpression at
;; point into one line separated each one by a space.
;;
;; - `srefactor-elisp-multi-line': Transform all sub-sexpressions current sexpression
;; - at point into multiple lines separated. If the head symbol belongs to the
;; - list `srefactor-elisp-symbol-to-skip', then the first N next symbol/sexpressions
;; - (where N is the nummber associated with the head symbol as stated in the
;; - list) are skipped before a newline is inserted.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:
(require 'semantic/bovine/el)

(defcustom srefactor-elisp-symbol-to-skip '(("progn" . 0)
                                            ("cond" . 0)
                                            ("save-excursion" . 0)
                                            ("unwind-protect" . 0)
                                            ("buffer-substring-no-properties" . 0)
                                            ("with-current-buffer" . 1)
                                            ("let" . 1)
                                            ("let*" . 1)
                                            ("if" . 1)
                                            ("while" . 1)
                                            ("when" . 1)
                                            ("unless" . 1)
                                            ("equal" . 2)
                                            ("concat" . 2)
                                            ("member" . 2)
                                            ("eq" . 2)
                                            ("assoc" . 2)
                                            ("defun" . 2)
                                            ("lambda" . 2)
                                            ("defvar" . 2)
                                            ("string-match" . 2)
                                            ("defcustom" . 2)
                                            ("setq" . 2)
                                            ("setf" . 2)
                                            (">" . 2)
                                            ("<" . 2)
                                            ("<=" . 2)
                                            (">=" . 2)
                                            ("1" . 2)
                                            ("1" . 2)
                                            )
  "A list of pairs of a symbol and a number that denotes how many
  sexp to be skipped before inserting the first newline. ")

(defun srefactor-elisp-one-line ()
  "Transform all sub-sexpressions current sexpression at point
into one line separated each one by a space."
  (interactive)
  (let ((starting-point (progn
                          (unless (looking-at "(")
                            (backward-up-list))
                          (point)))
        (end-point (srefactor-one-or-multi-lines 'one-line)))
    (indent-region starting-point end-point)))

(defun srefactor-elisp-multi-line ()
  "Transform all sub-sexpressions current sexpression at point into multiple lines separated. If the head symbol belongs to the
list `srefactor-elisp-symbol-to-skip', then the first N next
symbol/sexpressions (where N is the nummber associated with the
head symbol as stated in the list) are skipped before a newline
is inserted."
  (interactive)
  (let ((starting-point (progn
                          (unless (looking-at "(")
                            (backward-up-list))
                          (point)))
        (end-point (srefactor-one-or-multi-lines 'multi-line)))
    (indent-region starting-point end-point)))

(defun srefactor-one-or-multi-lines (format-type)
  "Turn the current sexpression into one line/multi-line depends
on the value of FORMAT-TYPE. If FORMAT-TYPE is 'one-line,
transforms all sub-sexpressions of the same level into one
line. If FORMAT-TYPE is 'multi-line, transforms all
sub-sexpressions of the same level into multiple lines.

Return the position of last closing sexp."
  (let* ((orig-point (point)) (tag-start (progn
                                           (unless (looking-at "(")
                                             (backward-up-list))
                                           (point)))
         (tag-end (save-excursion
                    (forward-sexp)
                    (point)))
         (lexemes (semantic-emacs-lisp-lexer tag-start
                                             tag-end
                                             1))
         (first-symbol (cadr lexemes))
         (first-symbol-name (buffer-substring-no-properties
                             (semantic-lex-token-start first-symbol)
                             (semantic-lex-token-end first-symbol)))
         (second-token (caddr lexemes))
         (tmp-buf (generate-new-buffer (make-temp-name "")))
         token-str
         ignore-pair
         token
         ignore-num)
    (unwind-protect
        (progn
          (while lexemes
            (setq token (pop lexemes))
            (setq token-str (if token
                                (buffer-substring-no-properties
                                 (semantic-lex-token-start token)
                                 (semantic-lex-token-end token))
                              ""))
            (let* ((token-type (car token)) (next-token (car lexemes))
                   (next-token-type (car next-token))
                   (next-token-str (if next-token
                                       (buffer-substring-no-properties
                                        (semantic-lex-token-start next-token)
                                        (semantic-lex-token-end next-token))
                                     "")))
              (with-current-buffer tmp-buf
                (insert token-str)
                (cond
                 ((member (concat token-str next-token-str) '("1-" "1+"))
                  (goto-char (semantic-lex-token-end next-token))
                  (insert (concat next-token-str "\n\n"))
                  (pop lexemes))
                 ((or (and (eq token-type 'punctuation)
                           (equal token-str "'"))
                      (eq token-type 'open-paren)
                      (eq token-type 'close-paren)
                      (eq next-token-type 'close-paren))
                  "")
                 ((eq format-type 'one-line) (insert " "))
                 ((eq format-type 'multi-line)
                  (if (and (eq token-type 'symbol)
                           (string-match ":.*" token-str))
                      (insert " ")
                    (insert "\n")))))))
          (goto-char tag-start)
          (kill-region tag-start
                       tag-end)
          (save-excursion
            (insert (with-current-buffer tmp-buf
                      (buffer-substring-no-properties
                       (point-min)
                       (point-max))))
            (when (eq format-type 'multi-line)
              (goto-char tag-start)
              (cond
               ((setq ignore-pair (assoc first-symbol-name srefactor-elisp-symbol-to-skip))
                (save-excursion
                  (setq ignore-num (cdr ignore-pair))
                  (while (> ignore-num 0)
                    (forward-line 1)
                    (delete-indentation)
                    (setq ignore-num (1- ignore-num)))))
               ((not (member (car second-token) '(close-paren 'open-paren 'string)))
                (forward-line 1)
                (delete-indentation))
               )))
          (goto-char tag-start)
          (forward-sexp)
          (setq tag-end (point))
          (setq lexemes (semantic-emacs-lisp-lexer tag-start
                                                   tag-end
                                                   1))
          (dolist (token (reverse lexemes))
            (when (and (eq (car token) 'semantic-list)
                       (> (- (semantic-lex-token-end token)
                             (semantic-lex-token-end token))
                          1))
              (goto-char (semantic-lex-token-start token))
              (srefactor-one-or-multi-lines format-type)))
          (goto-char tag-start)
          (forward-sexp)
          (setq tag-end (point))
          (goto-char (+ tag-start
                        (- orig-point
                           tag-start)))
          tag-end)
      (kill-buffer tmp-buf))))

(provide 'srefactor-elisp)

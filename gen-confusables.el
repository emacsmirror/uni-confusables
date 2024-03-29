;;; gen-confusables.el --- generate uni-confusables.el from confusables.txt  -*- lexical-binding: t; -*-

;; Copyright (C) 2011, 2012, 2014, 2022  Free Software Foundation, Inc.

;; Author: Teodor Zlatanov <tzz@lifelogs.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)

(defvar gen-confusables-char-table-single)
(defvar gen-confusables-char-table-multiple)

(defun gen-confusables-read (file)
  (interactive "fConfusables filename: \n")
  (cl-flet ((reader (h) (string-to-number h 16)))
    (let ((stable (make-char-table 'confusables-single-script))
          (mtable (make-char-table 'confusables-multiple-script))
          (count 0)
          (confusable-line-regexp (concat "^\\([[:xdigit:]]+\\)" ; \x+
                                          " ;\t"
                                          ;; \x+ separated by spaces
                                          "\\([[:space:][:xdigit:]]+\\)"
                                          " ;\t"
                                          "\\([SM]\\)[LA]"))) ; SL, SA, ML, MA
      (setq gen-confusables-char-table-single stable)
      (setq gen-confusables-char-table-multiple mtable)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward confusable-line-regexp nil t)
          (cl-incf count)
          (when (and (called-interactively-p 'interactive)
                     (zerop (mod count 100)))
            (message "processed %d lines" count))
          (let* ((from (match-string 1))
                 (to (match-string 2))
                 (class (match-string 3))
                 (table (if (string-equal "S" class) stable mtable)))
            (set-char-table-range
             table
             (reader from)
             (concat (mapcar #'reader (split-string to))))))))))

(defun gen-confusables-write (file)
  (interactive "FDumped filename: \n")
  (let ((coding-system-for-write 'utf-8-emacs))
    (with-temp-file file
      (insert ";;; uni-confusables.el --- Unicode confusables table  -*- lexical-binding: t -*-
;; Copyright (C) 1991-2009, 2010 Unicode, Inc.
;; This file was generated from a local copy of the Unicode confusables
;; list (covered by the Unicode copyright terms in copyright.html)
;; which was retrieved from
;; http://www.unicode.org/Public/security/revision-04/confusables.txt
;; and mechanically from the source file
;; gen-confusables.el.  The copyright and permissions are the same
;; as for gen-confusables.el.

;; Version: 0.3
;; Maintainer: Teodor Zlatanov <tzz@lifelogs.com>

;;; Code:\n\n")
      (dolist (type '(single multiple))
        (let* ((tablesym (intern (format "uni-confusables-char-table-%s" type)))
               (oursym (intern (format "gen-confusables-char-table-%s" type)))
               (ourtable (symbol-value oursym))
               (tablename (symbol-name tablesym))
               (prop (format "confusables-%s-script" type))
               props)
          (insert (format "(defvar %s (make-char-table '%s))\n\n"
                          tablename prop))
          (map-char-table
           (lambda (k v) (setq props (cons k (cons v props))))
           ourtable)

          (insert (format "(let ((k nil) (v nil) (ranges '(\n"))
	  (let ((i 0))
	    (dolist (p props)
	      (insert " ")
	      (prin1 p (current-buffer))
	      (when (zerop (mod (setq i (1+ i)) 10))
		(insert "\n"))))
	  (insert ")))\n")
          (insert (format "
  (while ranges
     (setq k (pop ranges)
           v (pop ranges))
     (set-char-table-range %s k v)))\n\n" tablename))

          (insert (format "(ert-deftest uni-confusables-test-%s ()\n" type))

          (dolist (offset '(100 200 800 3000 3500))
            (insert (format "
  (should (string-equal
           (char-table-range %s %d)
           %S))\n"
                            tablename
                            (nth (* 2 offset) props)
                            (nth (1+ (* 2 offset)) props))))
          (insert ")\n\n")))
      ;; Use \s escapes in the string, so that this text isn't mis-recognized
      ;; as applying to this file, but only to the generated file.
      (insert "
;;\sLocal\sVariables:
;;\scoding: utf-8
;;\sno-byte-compile: t
;;\sEnd:

(provide 'uni-confusables)

;;; uni-confusables.el ends here\n"))))

(provide 'gen-confusables)
;;; gen-confusables.el ends here

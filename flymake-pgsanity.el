;;; flymake-pgsanity.el --- A pgsanity Flymake backend  -*- lexical-binding: t; -*-

;; Copyright (c) 2024 Micah Elliott

;; Author: Micah Elliott <mde@micahelliott.com>
;; Maintainer: Micah Elliott <mde@micahelliott.com>
;; Homepage: https://github.com/micahelliott/flymake-pgsanity
;; Package-Requires: ((emacs "27.1"))
;; Package-Version: 0.1

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

;; Usage:
;;   (require 'flymake-pgsanity)
;;   (add-hook 'sql-mode-hook 'flymake-pgsanity-setup)
;;
;; See the Homepage for details on using this with templated SQL such as
;; HugSQL, how to customize/use its provided wrapper script, and some syntax
;; and CI recipes.
;;
;; Derived largely from ruby example:
;; https://www.gnu.org/software/emacs/manual/html_node/flymake/An-annotated-example-backend.html

;;; Code:

(require 'cl-lib)

(defvar-local pgsanity--flymake-proc nil)

;; (message "loading flymake-pgsanity package")

(defgroup flymake-pgsanity nil
  "Pgsanity backend for Flymake."
  :prefix "flymake-pgsanity-"
  :group 'tools)

(defcustom flymake-pgsanity-program
  "huglint"
  "Name of to the `sqllint' executable."
  ;; Alternatives are: huglint (for hugsql preprocessing), or a script of your own.
  :type 'string)


(defun flymake-pgsanity (report-fn &rest _args)
  ;; (message "running flymake-pgsanity")
  ;; Not having an interpreter is a serious problem
  (unless (executable-find flymake-pgsanity-program)
    (error "Could not find '%s' executable" flymake-pgsanity-program))
  ;; If a live process launched in an earlier check was found, that
  ;; process is killed.  When that process's sentinel eventually runs,
  ;; it will notice its obsoletion, since it have since reset
  ;; `flymake-pgsanity-proc' to a different value
  (when (process-live-p pgsanity--flymake-proc) (kill-process pgsanity--flymake-proc))
  ;; Save the current buffer, the narrowing restriction, remove any narrowing restriction.
  (let ((source (current-buffer)))
    (save-restriction
      (widen)
      ;; Reset the `pgsanity--flymake-proc' process to a new process calling the lint tool.
      (setq
       pgsanity--flymake-proc
       (make-process
        :name "flymake-pgsanity" :noquery t :connection-type 'pipe
        :buffer (generate-new-buffer " *flymake-pgsanity*") ; Make output go to a temporary buffer.
        :command (list flymake-pgsanity-program)
        :sentinel
        (lambda (proc _event)
          ;; Check that the process has indeed exited, as it might be simply suspended.
          (when (memq (process-status proc) '(exit signal))
            (unwind-protect
                ;; Only proceed if `proc' is the same as `pgsanity--flymake-proc',
                ;; which indicates that `proc' is not an obsolete process.
                (if (with-current-buffer source (eq proc pgsanity--flymake-proc))
                    (with-current-buffer (process-buffer proc)
                      (goto-char (point-min))
                      ;; Parse the output buffer for diagnostic's messages and locations,
                      ;; collect them in a list of objects, and call `report-fn'.
                      (cl-loop
                       ;; pgsanity output: line 5: ERROR: syntax error at or near ","
                       ;; while (search-forward-regexp "^line \\([0-9]+\\): \\(ERROR\\): \\(.*\\)$" nil t)
                       ;; ecpg output:     stdin:424: ERROR: syntax error at or near ","
                       while (search-forward-regexp "^stdin:\\([0-9]+\\): \\(ERROR\\): \\(.*\\)$" nil t)
                              ;; "^\\(?:.*.rb\\|-\\):\\([0-9]+\\): \\(.*\\)$"
                       for msg = (match-string 3)
                       for (beg . end) = (flymake-diag-region source (string-to-number (match-string 1)))
                       for type = (if (string-match "^warning" msg) :warning :error)
                       when (and beg end)
                       collect (flymake-make-diagnostic source beg end type msg)
                       into diags
                       finally (funcall report-fn diags)))
                  (flymake-log :warning "Canceling obsolete check %s" proc))
              ;; Cleanup the temporary buffer used to hold the check's output.
              (kill-buffer (process-buffer proc)))))))
      ;; Send the buffer contents to the process's stdnin, followed by an EOF.
      (process-send-region pgsanity--flymake-proc (point-min) (point-max))
      (process-send-eof pgsanity--flymake-proc))))

(defun pgsanity-setup-flymake-backend ()
  "Add pgsanity to diagnostics."
  (add-hook 'flymake-diagnostic-functions 'flymake-pgsanity nil t))

;; (add-hook 'sql-mode-hook 'pgsanity-setup-flymake-backend)

;;;###autoload
(defun flymake-pgsanity-setup ()
  "Enable pgsanity flymake backend."
  (add-hook 'flymake-diagnostic-functions #'flymake-pgsanity nil t))

(provide 'flymake-pgsanity)
;;; flymake-pgsanity.el ends here

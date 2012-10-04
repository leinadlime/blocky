;;; blocky.el --- Emacs tools for blocky

;; Copyright (C) 2006, 2007, 2008, 2009, 2010 David O'Toole

;; Author: David O'Toole <dto@gnu.org>
;; Keywords: lisp, oop, extensions
;; Version: 0.1

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'rx)
(require 'cl)
(require 'color-theme-blocky)

(defun eval-in-cl (cl-expression-string &optional process-result-values)
  (slime-eval-async `(swank:eval-and-grab-output ,cl-expression-string)
    (lexical-let  ((here (current-buffer))
                   (process-result-values process-result-values))
      (lambda (result-values)
	(when process-result-values
	  (set-buffer here)
	  (funcall process-result-values (rest result-values)))))))

(defun blocky-insinuate-lisp ()
  (interactive)
  (add-hook 'lisp-mode-hook
	    #'(lambda ()
		(add-to-list 'imenu-generic-expression 
			     `("Methods" ,(rx (sequence "(" (group "define-method")
							(one-or-more space)
							(group (one-or-more (not (any space)))
							       (one-or-more space)
							       (one-or-more (not (any space))))))
					 2))
		(add-to-list 'imenu-generic-expression 
			     `("Blocks" ,(rx (sequence "(" (group "define-block")
						       (zero-or-more "-macro")
						       (one-or-more space)
						       (zero-or-one "(")
						       (group (one-or-more (or "-" (any word))))))
					2))
		(imenu-add-menubar-index)))
  (defadvice slime-compile-defun (after blocky activate)
    (eval-in-cl "(blocky:update-parameters)")))

(blocky-insinuate-lisp)

;;; Font-locking

;; Put this in your emacs initialization file to get the highlighting:
;; (add-hook 'emacs-lisp-mode-hook #'blocky-do-font-lock)

(defvar blocky-font-lock-keywords
  `((,(rx (sequence "(" (group "define-method")
		   (one-or-more space)
		   (group (one-or-more (not (any space))))
		   (one-or-more space)
		   (group (one-or-more (not (any space))))))
     (1 font-lock-keyword-face)
     (2 font-lock-function-name-face) ;; this still doesn't work
				      ;; properly.
     (3 font-lock-type-face))
    (,(rx (sequence "(" (group "define-prototype")
		   (one-or-more space)
		   (group (one-or-more (not (any space))))))
      (1 font-lock-keyword-face)
      (2 font-lock-type-face))
    (,(rx (sequence "(" (group "define-block-macro")
		   (one-or-more space)
		   (group (one-or-more (not (any space))))))
      (1 font-lock-keyword-face)
      (2 font-lock-type-face))
    (,(rx (sequence "(" (group "define-block")
		   (one-or-more space)
		   (group (one-or-more (not (any space))))))
      (1 font-lock-keyword-face)
      (2 font-lock-type-face))
;    ("\\<\\(\<[^<>]*\>\\)\\>" (1 font-lock-preprocessor-face))
    ("(.*\\(\>\>\\>\\)" (1 font-lock-type-face))))

(defun blocky-do-font-lock ()
  (interactive)
  "Highlight the keywords used in prototype-oriented programming."
  (font-lock-add-keywords nil blocky-font-lock-keywords))

;; Emacs glass frame is transparent

(defun glass-initialize ()
  (setq slime-enable-evaluate-in-emacs t))

(defvar *glass-transparent-alpha* 50)
(defvar *glass-opaque-alpha* 100)

(defun glass-transparent ()
  (interactive)
  (set-frame-parameter nil 'alpha *glass-transparent-alpha*))

(defun glass-opaque ()
  (interactive)
  (set-frame-parameter nil 'alpha *glass-opaque-alpha*))

;;; Glass frame can be fixed on top of other windows

(defvar *wm-toggle* 2)
(defvar *wm-add* 1)
(defvar *wm-remove* 0)

(defun* glass-set-on-top-property (&optional frame (state *wm-toggle*))
  (x-send-client-message
   frame 0 frame "_NET_WM_STATE" 32
   (list state "_NET_WM_STATE_ABOVE" 0 1)))

(defun glass-on-top (&optional frame)
  (glass-set-on-top-property frame *wm-add*))

(defun glass-off-top (&optional frame)
  (glass-set-on-top-property frame *wm-add*))

;;; Without window-borders

(defun make-hinted-frame (hints)
   (let ((frame (make-frame '((visibility . nil)))))
     (prog1 frame
       (x-change-window-property "_MOTIF_WM_HINTS" hints ff
                                 "_MOTIF_WM_HINTS" 32 t)
       (make-frame-visible frame))))

(defvar *wm-without-decoration* '(2 0 0 0 0))

(defun make-frame-without-decoration ()
  (interactive)
  (make-hinted-frame *wm-without-decoration*))

(defun glass-focus (&optional frame)
  (redirect-frame-focus frame)
  (raise-frame frame)
  (make-frame-visible frame)
  (select-frame frame)
  (select-frame-set-input-focus frame))

(make-variable-buffer-local (defvar *glass-local-mode-line-format* nil))

(defvar *glass-frame* nil)

(defun* glass-show (&optional (buffer (current-buffer)))
  (let ((frame (make-frame-without-decoration)))
    (setf *glass-frame* frame)
    (delete-other-windows)
    (switch-to-buffer buffer)
    (setq indicate-buffer-boundaries 'left)
    (setq *glass-local-mode-line-format* mode-line-format)
    (setq mode-line-format nil)
    (glass-transparent)
    (glass-focus frame)
    (glass-on-top)))
    
(defun* glass-hide ()
    (when *glass-frame*
      (when (null mode-line-format)
	(setq mode-line-format *glass-local-mode-line-format*))
      (delete-frame *glass-frame*)
      (setf *glass-frame* nil)))

;;; Grabbing UUIDs and inspecting the corresponding objects

(defvar blocky-uuid-regexp 
  "[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]")

(defun blocky-inspect-uuid (uuid)
  (interactive "sInspect blocky UUID: ")
  (if (null uuid)
      (message "No UUID provided.")
      (progn 
	(assert (stringp uuid))
	(slime-inspect
	 (format "(blocky::find-object %S)" uuid)))))

(defun blocky-uuid-at-point ()
  (let ((thing (thing-at-point 'word)))
    (when (and (not (null thing))
	       (string-match blocky-uuid-regexp thing))
      thing)))
	  
(defun blocky-uuid-on-this-line ()
  (string-match blocky-uuid-regexp
		(buffer-substring-no-properties
		 (point-at-bol)
		 (point-at-eol))))

(defun blocky-inspect ()
  (interactive)
  (blocky-inspect-uuid (or (blocky-uuid-at-point)
			   (blocky-uuid-on-this-line))))

(provide 'blocky)
;;; blocky.el ends here

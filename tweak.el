;;; tweak.el --- extensible emacs code tweaking interface 
;;;              with change visualization hooks

;; Copyright (C) 2012  David O'Toole

;; Author: David O'Toole <dto@ioforms.org>
;; Keywords: tools, lisp, mouse

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

;;; Code:

(require 'cl)
(require 'slime)

(defvar tweak-package :blocky)

(defun tweak (&rest data)
  (slime-eval `(tweak ,@data) tweak-package))

(defmacro define-simple-tweak (keyword)
  `(defun ,(intern (concat "blocky-" (symbol-name keyword)))
       arglist
     (tweak 




(provide 'tweak)
;;; tweak.el ends here

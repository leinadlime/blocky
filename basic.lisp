;;; basic.lisp --- interactive blocks for basic lisp data types

;; Copyright (C) 2013  David O'Toole

;; Author: David O'Toole <dto@ioforms.org>
;; Keywords: 

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

(in-package :blocky)

(defparameter *socket-size* 16)
(defparameter *active-prompt-color* "red")
(defparameter *inactive-prompt-color* "gray10")
(defparameter *prompt-cursor-inactive-color* "gray50")

(defparameter *default-prompt-text-color* "white")
(defparameter *default-prompt-outside-text-color* "gray20")

(defparameter *default-prompt-label-color* "white")

(defparameter *default-entry-text-color* "white")
(defparameter *default-entry-label-color* "white")
;(defparameter *default-prompt-string* "     ")
(defparameter *default-prompt-string* "Command: ")

(defparameter *default-prompt-margin* 4)

(defparameter *default-prompt-history-size* 100)
(defparameter *default-cursor-width* 1)

;;; Vertically stacked list of blocks

(define-block list
  (spacing :initform 1)
  (dash :initform 2)
  (frozen :initform nil)
  (orientation :initform :vertical)
  (operation :initform :empty-list)
  (category :initform :structure))

(defun make-visual-list ()
  (clone "BLOCKY:LIST"))

(define-method frozenp list () %frozen)

(define-method freeze list ()
  (setf %frozen t)
  (mapc #'pin %inputs))

(define-method unfreeze list ()
  (setf %frozen nil)
  (mapc #'unpin %inputs))

;; (define-method pick list ()
;;   (if %parent
;;       (if (phrasep %parent)

(define-method evaluate list () 
  (mapcar #'evaluate %inputs))

(define-method recompile list () 
  "Return the computed result of this block.  By default, all the
inputs are evaluated."
  (mapcar #'recompile %inputs))

(defparameter *null-display-string* "   ")

(define-method set-orientation list (orientation)
  (assert (member orientation '(:horizontal :vertical)))
  (setf %orientation orientation))

(define-method toggle-orientation list ()
  (setf %orientation 
	(ecase %orientation
	  (:horizontal :vertical)
	  (:vertical :horizontal))))

(define-method can-accept list () 
  (not %frozen))

(define-method accept list (input &optional prepend)
  (assert (blockyp input))
  (when (not %frozen)
    (prog1 t
      (invalidate-layout self)
      (with-fields (inputs) self
	(if inputs
	    ;; we've got inputs. add it to the list (prepending or not)
	    (progn 
	      (assert (valid-connection-p self input))
	      ;; set parent if necessary 
	      (when (get-parent input)
		(unplug-from-parent input))
	      (set-parent input self)
	      (setf inputs 
		    (if prepend
			(append (list input) inputs)
			(append inputs (list input)))))
	    ;; no inputs yet. make a single-element inputs list
	    (progn
	      (setf inputs (list input))
	      (set-parent input self)))))))

(define-method take-first list ()
  (with-fields (inputs) self
    (let ((block (first inputs)))
      (prog1 block
	(unplug self block)))))

(define-method get-length list ()
  (length %inputs))

(define-method header-height list () 0)

(define-method label-width list ()
  (+ (* 2 *dash*)
     (expression-width *null-display-string*)))

(define-method layout-as-null list ()
  (with-fields (height width) self
    (setf width (+ (* 4 *dash*)
		   (font-text-width *null-display-string*
				      *font*))
	  height (+ (font-height *font*) (* 4 *dash*)))))

(define-method layout-vertically list ()
  (with-fields (x y height width spacing inputs dash) self
    (flet ((ldash (&rest args)
	     (apply #'dash 1 args)))
    (let* ((header-height (header-height self))
	   (y0 (+ y (if (zerop header-height) spacing (dash 2 header-height))))
	   (line-height (font-height *font*)))
      (setf height (ldash))
      (setf width (dash 6))
      (dolist (element inputs)
	(move-to element (ldash x) y0)
	(layout element)
	(incf height (field-value :height element))
;	(incf height spacing)
	(incf y0 (field-value :height element))
	(setf width (max width (field-value :width element))))
      (incf width (dash 2))))))

(define-method layout-horizontally list ()
  (with-fields (x y height spacing width inputs dash) self
    (flet ((ldash (&rest args) (apply #'+ %spacing args)))
      (let ((x0 (+ x spacing))
	    (y0 (ldash y))
	    (line-height (font-height *font*)))
	(setf height (ldash line-height))
	(setf width (dash 2))
	(dolist (element inputs)
	  (move-to element x0 y0)
	  (layout element)
	  (setf height (max height (+ (ldash) (field-value :height element))))
	  (incf x0 (field-value :width element))
	  (incf width (field-value :width element)))
;	  (incf width spacing))
	(incf height spacing)))))

(define-method layout list ()
  (with-fields (inputs) self
    (if (null inputs)
	(layout-as-null self)
	(ecase %orientation
	  (:horizontal (layout-horizontally self))
	  (:vertical (layout-vertically self))))))

(define-method insert-before list (index object)
  (with-fields (inputs) self
    (setf inputs
	  (append (subseq inputs 0 index)
		  (list object)
		  (subseq inputs index)))))

(define-method draw-header list () 0)

(define-method draw list ()
  (with-fields (inputs) self
    (unless %no-background 
      (draw-background self))
    (if (null inputs)
	(draw-label-string self *null-display-string*)
	(dolist (each inputs)
	  (draw each)))))

(define-method initialize list (&rest blocks)
  (apply #'block%initialize self blocks))
;  (freeze self))

(defmacro deflist (name &rest body)
  `(define-block (,name :super list) ,@body))

(defun null-block () (new 'list))

;;; Horizontal list

(defun hlist (&rest args)
  (let ((list (apply #'new 'list args)))
    (prog1 list 
      (setf (field-value :orientation list) :horizontal))))

;;; The prompt is the underlying implementation for our word widgets.

(define-block prompt
  (text-color :initform "gray20")
  (point :initform 0 :documentation "Integer index of cursor within prompt line.")
  (line :initform "" :documentation "Currently edited command line.")
  (background :initform t)
  (methods :initform '(:toggle-read-only))
  (error-output :initform "")
  (minimum-width :initform 100)
  (text-color :initform *default-prompt-text-color*)
  (label-color :initform *default-prompt-label-color*)
  options label 
  (pinned :initform nil)
  (prompt-string :initform *default-prompt-string*)
  (category :initform :data)
  (history :documentation "A queue of strings containing the command history.")
  (history-position :initform 0))

(define-method accept prompt (&rest args)
  nil)

(define-method exit prompt ()
  (clear-line self))

(define-method goto prompt ()
  (say self "Enter command below at the >> prompt. Press ENTER when finished, or CONTROL-X to cancel."))

(define-method say prompt (&rest args)
  (apply #'message args))

(define-method initialize prompt ()
  (block%initialize self)
  (when (not (has-local-value :history self))
    (setf %history (make-queue :max *default-prompt-history-size* :count 0)))
  (install-text-keybindings self))

(define-method handle-event prompt (event)
  (unless %read-only
    (handle-text-event self event)))

(define-method forward-char prompt ()
  (setf %point (min (1+ %point)
		     (length %line))))

(define-method backward-char prompt ()
  (setf %point (max 0 (1- %point))))

(define-method insert prompt (string)
  (setf %line (concatenate 'string
			    (subseq %line 0 %point)
			    string
			    (subseq %line %point)))
  (incf %point (length string)))

(define-method backward-delete-char prompt ()
  (when (< 0 %point) 
    (setf %line (concatenate 'string
			      (subseq %line 0 (1- %point))
			      (subseq %line %point)))
    (decf %point)))

(define-method delete-char prompt ()
  (with-fields (point line) self
    (when (<= 0 point (1- (length line)))
      (setf line (concatenate 'string
			      (subseq line 0 point)
			      (subseq line (1+ point)))))))

(define-method print-data prompt (data &optional comment)
  (dolist (line (split-string-on-lines (write-to-string data :circle t :pretty t :escape nil :lines 5)))
    (say self (if comment ";; ~A"
		  " ~A") line)))

(define-method do-sexp prompt (sexp))

(define-method read-expression prompt (input-string)
  (handler-case 
      (program-from-string input-string)
    (condition (c)
      (format *error-output* "~S" c))))

(define-method print-expression prompt (sexp)
  (format nil "~S" sexp))

(define-method enter prompt (&optional no-clear)
  (labels ((print-it (c) 
	     (message "~A" c)))
    (let* ((line %line)
	   (sexp (read-expression self line)))
      (unless no-clear (clear-line self))
      (with-output-to-string (*standard-output*)
	(when sexp (do-sexp self sexp))))
    (do-after-evaluate self)))

;; (setf %error-output
;; (if *debug-on-error*
;;     (do-sexp self sexp)
;;     (handler-case
;; 	(handler-bind (((not serious-condition)
;; 			 (lambda (c) 
;; 			   (print-it c)
;; 			   ;; If there's a muffle-warning
;; 			   ;; restart associated, use it to
;; 			   ;; avoid double-printing.
;; 			   (let ((r (find-restart 'muffle-warning c)))
;; 			     (when r (invoke-restart r))))))
;; 	  (do-sexp self sexp))
;;       (serious-condition (c)
;; 	(print-it c))))
;; (queue line %history))))


(define-method newline prompt ()
  (enter self))

(define-method do-after-evaluate prompt ()
  nil)

(define-method history-item prompt (n)
  (assert (integerp n))
  (assert (not (minusp n)))
  (nth (- (queue-count %history) n)
       (queue-head %history)))

(define-method forward-history prompt ()
  (when (> %history-position 0)
    (setf %line (history-item self (progn (decf %history-position)
					   %history-position)))
    (when (null %line) (setf %line ""))
    (setf %point (length %line))))
 
(define-method backward-history prompt ()
  (when %history 
    (when (numberp %history-position)
      (when (< %history-position (queue-count %history))
	(setf %line (history-item self (progn (incf %history-position)
					      %history-position)))
	(setf %point (length %line))))))

(define-method previous-line prompt ()
  (backward-history self))

(define-method next-line prompt ()
  (forward-history self))

(define-method clear-line prompt ()
  (setf %line "")
  (setf %point 0)
  (setf %history-position 0))

(define-method end-of-line prompt ()
  (setf %point (length %line)))

(define-method beginning-of-line prompt ()
  (setf %point 0))

(define-method draw-cursor prompt 
    (&key (x-offset 0) (y-offset 0)
	  color blink)
  (with-fields (x y width height clock point parent background
		  prompt-string line) self
    (draw-cursor-glyph self
     ;;
     (+ x (or x-offset 0)
	(font-text-width (if (<= point (length line))
			     (subseq line 0 point)
			     " ")
			 *font*)
	(if x-offset 0 (font-text-width prompt-string *font*)))
     ;;
     (+ y (or y-offset 0) *default-prompt-margin*)
     *default-cursor-width*
     ;; (font-text-width 
     ;;  (string (if (< point (length line))
     ;; 		   (aref line 
     ;; 			 (max (max 0 
     ;; 				   (1- (length line)))
     ;; 			      point))
     ;; 		   #\Space))
     (* (font-height *font*) 0.8)
     :color color
     :blink blink)))

(define-method label-width prompt () 
  (font-text-width %prompt-string *font*))

(define-method label-string prompt () %prompt-string)

(define-method draw-border prompt ())

(define-method draw-hover prompt ())

(define-method tap prompt (mouse-x mouse-y)
  ;(declare (ignore mouse-y))
  (if %read-only
      (tap%super self mouse-x mouse-y)
      (with-fields (x y width height clock point parent background
		      line) self
	;; find the left edge of the data area
	(let* ((left (+ x (label-width self) (dash 4)))
	       (tx (- mouse-x left)))
	  ;; which character was clicked?
	  (let ((click-index 
		  (block measuring
		    (dotimes (ix (length line))
		      (when (< tx (font-text-width 
				   (subseq line 0 ix)
				   *font*))
			(return-from measuring ix))))))
	    (if (numberp click-index)
		(setf point click-index)
		(setf point (length line))))))))

(define-method layout prompt ())

(define-method update-layout-maybe prompt ()
  (with-fields (line) self
    (resize self 
	    (+ 12 (* 5 *dash*)
	       (font-text-width line *font*)
	       (font-text-width *default-prompt-string* *font*))
	    (+ (* 2 *default-prompt-margin*) (font-height *font*)))))

(define-method draw-input-area prompt (state)
  ;; draw shaded area for data entry.
  ;; makes the cursor show up a bit better too.
  (with-fields (x y parent label line) self
    (assert (not (null line)))
    (let ((label-width (label-width self))
	  (line-width (font-text-width line *font*)))
      (draw-box (dash 0.5 x label-width)
		(dash 0.2 y)
		(dash 2 line-width)
		(dash 0.3 (font-height *font*))
		:color (ecase state
			 (:active *active-prompt-color*)
			 (:inactive 
			  (find-color 
			   (or 
			    (unless (is-a 'buffer %parent)
			      %parent)
			    self) :shadow)))))))

(define-method draw-indicators prompt (state)
  (with-fields (x y options text-color width parent height line) self
    (let ((label-width (label-width self))
	  (line-width (font-text-width line *font*))
	  (fh (font-height *font*)))
      ;; (draw-indicator :top-left-triangle
      ;; 		      (dash 1 x 1 label-width)
      ;; 		      (dash 1 y)
      ;; 		      :state state)
      (draw-indicator :bottom-right-triangle
		      (dash 1 x -2 label-width line-width)
		      (+ y -2 fh)
		      :state state))))

(define-method draw-focus prompt () 
  (unless %read-only
    (with-fields (cursor-clock x y width line parent) self
      (let* ((label (label-string self))
	     (label-width (label-width self))
	     (line-width (font-text-width line *font*)))
	;; draw shaded area for input
	(draw-input-area self :active)
	;; draw cursor.
	(update-cursor-clock self)
	(draw-cursor self 
		     :x-offset
		     (dash 3 (font-text-width label *font*))
		     :blink t)
	;; draw highlighted indicators
	(draw-indicators self :active)
	;; redraw content (but not label)
	(draw self :nolabel)))))

(define-method draw prompt (&optional nolabel)
  (with-fields (x y width height point parent background
		  line prompt-string) self
    (when (null line) (setf line ""))
    (let ((strings-y *default-prompt-margin*))
      (unless nolabel
	;; draw prompt string
	(assert (stringp %text-color))
	(draw-string prompt-string
		     (+ x *default-prompt-margin*)
		     (+ y strings-y)
		     :color (if (treep parent)
				%text-color
				*default-prompt-outside-text-color*)
		     :font *font*)
 	(update-layout-maybe self)
	;; draw background for input
	(unless %read-only
	  (draw-input-area self :inactive)
	  (draw-indicators self :inactive)))
      ;; draw current command line text
      (when (null line) (setf line ""))
      (unless (zerop (length line))
	(draw-string line
		     (dash 1 x (label-width self))
		     (+ y strings-y)
		     :color %text-color
		     :font *font*)))))

;;; General-purpose data entry block for any type of word

(defun wordp (x) (has-tag x :word))

(define-block (entry :super prompt)
  (old-line :initform nil) 
  (tags :initform '(:word))
  (category :initform :data)
  (locked :initform nil)
  (pinned :initform nil)
  (minimum-width :initform 10)
  (text-color :initform *default-entry-text-color*)
  (label-color :initform *default-entry-label-color*)
  type-specifier value)

(define-method tap entry (x y)
  (setf (point) self))

(define-method scroll-tap entry (x y))

(define-method start-editing entry ()
  (set-read-only self nil)
  (setf %old-line (copy-tree %line))
  (grab-focus self))

(define-method finish-editing entry ()
  (setf %old-line nil)
  (set-read-only self t))

(define-method cancel-editing entry ()
  (when %old-line
    (setf %line (copy-tree %old-line))))

(define-method alternate-tap entry (x y)
  (execute (list %value)))

(define-method as-drag entry (x y)
  (declare (ignore x y)) 
  (pick self))

(define-method initialize entry 
    (&key value type-specifier options label label-color parent locked
    read-only)
  (initialize%super self)
  ;(assert (and value type-specifier))
  (when parent (setf %parent parent))
  (setf %type-specifier type-specifier
	%options options
	%locked locked
	%read-only read-only
	%value value)
  ;; fill in the input box with the value
  (setf %line (if (null value)
		  ""
		  ;; don't print symbol package names
		  (pretty-string
		   (if (and (symbolp value)
			    (not (keywordp value)))
		       (symbol-name value)
		       (format nil "~S" value)))))
		  ;; (if (stringp value)
		  ;;     ;; no extraneous quotes unless it's a general sexp entry
		  ;;     value
		  ;;     (format nil "~S" value))))
  (setf %label 
	(or label 
	    (getf options :label)))
  (when label-color (setf %label-color label-color)))

(define-method set-read-only entry (&optional (value t))
  (setf %read-only value))

(define-method evaluate entry ()
  %value)

(define-method set-value entry (value)
  (setf %value value)
  (setf %line (prin1-to-string value)))

(define-method get-value entry ()
  %value)

(define-method recompile entry ()
  %value)

(define-method label-string entry ()
  (or %label 
      (getf %options :label)
      ""))

(define-method can-pick entry () 
  t)
  
(define-method pick entry ()
  (if %pinned (pick %parent) self))
      
(define-method toggle-read-only entry ()
  (unless %locked
    (setf %read-only (if %read-only nil t))))

(define-method label-width entry () 0)
(define-method draw-label entry ())
		 
(define-method draw entry (&optional nolabel)
  (with-fields (x y options read-only 
		  text-color width background
		  parent height line) self
    (let ((label-width (label-width self))
	  (line-width (font-text-width line *font*)))
      ;; draw the label string 
      (let ((*text-baseline* (+ y (dash 1))))
	(unless nolabel 
	  (when (plusp (length %label))
	    (draw-label self))
	  ;; draw shaded area for input
	  (when (or (not background)
		    (not (phrasep %parent))
		    (not read-only))
	    (draw-input-area self :inactive)))
	    ;; ;; draw indicators
	    ;; (draw-indicators self :inactive)))
	;; draw current input string
	(when (null line) (setf line ""))
	(unless (zerop (length line))
	  (draw-string line
		       (+ (dash 1 x) label-width)
		       *text-baseline*
		       :color (find-color self :foreground)
		       :font *font*))))))
		 
(define-method draw-focus entry ()
  (unless %read-only 
    (with-fields (x y line) self
      (draw-input-area self :active)
      (let ((*text-baseline* (+ y (dash 1))))
	(unless (zerop (length line))
	  (draw-string line
		       (dash 1 x)
		       *text-baseline*
		       :color *default-prompt-text-color*
		       :font *font*))
	(draw-indicators self :active)
	(update-cursor-clock self)
	(draw-cursor self 
		     :x-offset
		     (dash 1)
		     :blink t)))))
  
(define-method draw-point entry ()
  (with-fields (x y width height) self
    (draw-box x y width height 
	      :color "white"
	      :alpha (min 0.7 (+ 0.2 (sin (/ *updates* 2)))))))

(define-method do-sexp entry (sexp)
  (with-fields (value type-specifier parent) self
    (assert (and (listp sexp) (= 1 (length sexp))))
    (let ((datum (first sexp)))
      (if (or (null type-specifier)
	      (type-check self datum))
	  (setf value datum)
	  (message "Warning: value entered does not match type ~S. Not storing value."
		   type-specifier))
      (when parent (child-updated parent self)))))
 
(define-method enter entry ()
  (unless %read-only
    (enter%super self :no-clear)))

(define-method layout entry ()
  (with-fields (height width value line) self
    (setf height (+ 1 (* 1 *dash*) (font-height *font*)))
    (setf width (+ 1 (* 2 *dash*)
		   (label-width self)
		   (max %minimum-width
			(font-text-width line *font*))))))

;;; Dropping words into phrases

(define-method accept entry (thing)
  (with-fields (parent) self
    (when (phrasep parent)
      (prog1 t
	(let ((index (position-within-parent self)))
	  (insert-before parent index thing))))))
		      
;;; Allow dragging the parent block more easily

(define-method hit entry (x y)
  (when (hit%super self x y)
    ;; always allow clicking data area
    (if (< x (+ %x (label-width self)))
	%parent
	self)))

(define-method type-check entry (datum)
  (typep datum %type-specifier))

;; ;; print any error output
;;   (when (and (stringp %error-output)
;; 	     (plusp (length %error-output)))
;;     (add-block (current-buffer) (new 'text %error-output) *pointer-x* *pointer-y*)))

;;; Easily defining new entry blocks

(defmacro defentry (name type value &rest specs)
  `(define-block (,name :super entry)
     (type-specifier :initform ',type)
     (value :initform ',value)
     ,@specs))

(defentry integer integerp 0)
(defentry number numberp 0)
(defentry non-negative-number (number 0 *) 0)
(defentry float floatp 0.0)
(defentry symbol symbolp nil 
  (category :initform :data))
(defentry positive-integer (integer 1 *) 1)
(defentry non-negative-integer (integer 0 *) 0)
(defentry string stringp "")
(defentry expression t nil 
  (category :initform :expression))

(define-method evaluate expression ()
  (eval (get-value self)))

;;; String display
 
(defentry label stringp "")
 
(define-method read-expression label (input-string)
  ;; pass-through; don't read string at all.
  input-string)
 
(define-method do-sexp label (sexp)
  (assert (stringp sexp))
  (setf %value sexp)
  (when %parent (child-updated %parent self)))

(define-method set-value label (value)
  (when (stringp value)
    (setf %value value)
    (setf %line value)))

;;; Creating word blocks from S-expressions
 
(defparameter *builtin-entry-types* 
  '(integer float string symbol number))
 
(defun data-block (datum)
  (typecase datum
    (symbol (new 'symbol :value datum :read-only t))
    (string (new 'string :value datum :read-only t))
    (number (new 'number :value datum :read-only t))
    (otherwise (new 'expression :value datum :read-only t))))

;;; basic.lisp ends here

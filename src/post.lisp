(in-package #:blog)

(defstruct post title date slug description draft html)

(defun escape (string)
  (with-output-to-string (out)
    (loop for c across string
          do (case c
               (#\& (write-string "&amp;" out))
               (#\< (write-string "&lt;" out))
               (#\> (write-string "&gt;" out))
               (#\" (write-string "&quot;" out))
               (t (write-char c out))))))

(defun read-data (stream)
  "Read one form as data: no read-time evaluation, symbols interned in BLOG."
  (let ((*read-eval* nil)
        (*package* (find-package '#:blog)))
    (read stream)))

;; Emits the markup highlight.js expects: the language class sits on <code>.
(defmethod 3bmd-code-blocks:render-code-block
    ((renderer (eql :hljs)) stream lang params code)
  (declare (ignore params))
  (format stream "~&<pre><code~@[ class=\"language-~a\"~]>~a</code></pre>~%"
          (and lang (escape lang)) (escape code)))

(defun markdown->html (text)
  (let ((3bmd-code-blocks:*code-blocks* t)
        (3bmd-code-blocks:*renderer* :hljs)
        (3bmd-tables:*tables* t))
    (with-output-to-string (out)
      (3bmd:parse-string-and-print-to-stream text out))))

(defun filename-slug (path)
  "2025-12-24-Lambda-Calculus.md => \"lambda-calculus\"."
  (let ((name (pathname-name path)))
    (string-downcase
     (if (and (> (length name) 11) (digit-char-p (char name 0)))
         (subseq name 11)
         name))))

(defun read-post (path)
  (with-open-file (in path :external-format :utf-8)
    (destructuring-bind (&key title date slug description draft) (read-data in)
      (unless (and title date)
        (error "~a: header needs :title and :date" path))
      (let ((body (make-string (file-length in))))
        (make-post :title title
                   :date date
                   :slug (or slug (filename-slug path))
                   :description description
                   :draft draft
                   :html (markdown->html (subseq body 0 (read-sequence body in))))))))

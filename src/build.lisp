(in-package #:blog)

(defun write-file (path string)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output :if-exists :supersede
                            :external-format :utf-8)
    (write-string string out)))

(defun copy-directory (from to)
  ;; DIRECTORY returns truenames, so FROM must be one too for ENOUGH-PATHNAME.
  (let ((from (uiop:truename* from)))
    (when from
      (copy-files from to))))

(defun copy-files (from to)
  (dolist (file (directory (merge-pathnames "**/*.*" from)))
    (unless (uiop:directory-pathname-p file)
      (let ((target (merge-pathnames (uiop:enough-pathname file from) to)))
        (ensure-directories-exist target)
        (uiop:copy-file file target)))))

(defun read-posts (dir)
  (sort (remove-if #'post-draft
                   (mapcar #'read-post (directory (merge-pathnames "*.md" dir))))
        #'string> :key #'post-date))

(defun build (&key (root (asdf:system-source-directory "blog"))
                (out (merge-pathnames "_site/" root)))
  "Generate the site from ROOT into OUT, replacing OUT."
  (let ((*print-pretty* nil)
        (*site* (with-open-file (in (merge-pathnames "site.lisp" root)
                                    :external-format :utf-8)
                  (read-data in)))
        (posts (read-posts (merge-pathnames "posts/" root))))
    (uiop:delete-directory-tree out :validate (lambda (dir)
                                                (search "_site" (namestring dir)))
                                    :if-does-not-exist :ignore)
    (copy-directory (merge-pathnames "static/" root) out)
    (write-file (merge-pathnames "index.html" out) (home-page posts))
    (dolist (post posts)
      (write-file (merge-pathnames (format nil "~a.html" (post-slug post)) out)
                  (post-page post)))
    (write-file (merge-pathnames "feed.xml" out) (feed posts))
    out))

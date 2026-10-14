;; Build the site into _site/: sbcl --non-interactive --load make.lisp
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(push (uiop:pathname-directory-pathname *load-truename*) asdf:*central-registry*)
(ql:quickload "blog" :silent t)
(format t "~a~%" (blog:build))

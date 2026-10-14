(in-package #:blog)

(defun feed-time (date)
  (format nil "~aT00:00:00~a" date (site :timezone)))

(defun feed (posts)
  (with-output-to-string (out)
    (format out "<?xml version=\"1.0\" encoding=\"utf-8\"?>~%~
<feed xmlns=\"http://www.w3.org/2005/Atom\">~%~
<title>~a</title>~%~
<link href=\"~a\" rel=\"self\"/>~%~
<link href=\"~a\"/>~%~
<id>~a</id>~%~
<updated>~a</updated>~%~
<author><name>~a</name></author>~%"
            (escape (site :title))
            (absolute-url "/feed.xml")
            (absolute-url "/")
            (absolute-url "/")
            (feed-time (if posts (post-date (first posts)) "1970-01-01"))
            (escape (site :author)))
    (dolist (post posts)
      (let ((url (absolute-url (format nil "/~a.html" (post-slug post)))))
        (format out "<entry>~%~
<title>~a</title>~%~
<link href=\"~a\"/>~%~
<id>~a</id>~%~
<updated>~a</updated>~%~
<content type=\"html\">~a</content>~%~
</entry>~%"
                (escape (post-title post)) url url
                (feed-time (post-date post))
                (escape (post-html post)))))
    (format out "</feed>~%")))

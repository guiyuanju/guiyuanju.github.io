(in-package #:blog)

(defvar *site* nil
  "Plist read from site.lisp.")

(defun site (key)
  (getf *site* key))

(defun absolute-url (path)
  (concatenate 'string (string-right-trim "/" (site :url)) path))

(defmacro with-page ((&key title description path buffer mode) &body body)
  "Render one Emacs-style frame: a buffer, its mode line, and the minibuffer."
  `(spinneret:with-html-string
     (:doctype)
     (:html :lang "en"
      (:head
       (:meta :charset "utf-8")
       (:meta :name "viewport" :content "width=device-width, initial-scale=1")
       (:title ,title)
       (let ((description ,description))
         (when description
           (:meta :name "description" :content description)
           (:meta :property "og:description" :content description)))
       (:meta :property "og:title" :content ,title)
       (:meta :property "og:url" :content (absolute-url ,path))
       (:link :rel "canonical" :href (absolute-url ,path))
       (:link :rel "alternate" :type "application/atom+xml"
              :title (site :title) :href "/feed.xml")
       (:link :rel "icon" :href "/logo.png")
       (:link :rel "stylesheet" :href "/assets/css/main.css")
       (:link :rel "stylesheet" :href "/assets/css/hljs.css"))
      (:body
       (:main.buffer ,@body)
       (:footer.mode-line
        (:span.modified "-")
        (:span.buffer-name ,buffer)
        (:span.position "L1")
        (:span.vc "main")
        (:span.mode ,mode))
       (:div.minibuffer :id "minibuffer")
       (:script :src "/assets/js/highlight.min.js")
       (:script :src "/assets/js/main.js")
       (let ((code (site :goatcounter)))
         (when code
           (:script :data-goatcounter
                    (format nil "https://~a.goatcounter.com/count" code)
                    :async t :src "//gc.zgo.at/count.js")))))))

(defun post-list (posts)
  (spinneret:with-html
    (:ul.post-list
     (dolist (post posts)
       (:li (:time :datetime (post-date post) (post-date post))
            " "
            (:a :href (format nil "/~a.html" (post-slug post))
                (post-title post)))))))

;; Dispatch happens outside with-html: inside it, (:section ...) and friends
;; would be read as tags, even as case keys.
(defun home-entry (entry)
  (destructuring-bind (kind label &optional url) entry
    (ecase kind
      (:text (spinneret:with-html (:li label)))
      (:link (spinneret:with-html (:li (:a :href url label)))))))

(defun home-section (section posts)
  (destructuring-bind (kind title &rest entries) section
    (ecase kind
      (:posts (spinneret:with-html
                (:section (:h2 title) (post-list posts))))
      (:section (spinneret:with-html
                  (:section (:h2 title)
                            (:ul (mapc #'home-entry entries))))))))

(defun home-page (posts)
  (with-page (:title (site :title) :description (site :description) :path "/"
              :buffer "~/" :mode "Dired")
    (:h1 (site :title))
    (dolist (section (site :home))
      (home-section section posts))))

(defun post-page (post)
  (with-page (:title (post-title post) :description (post-description post)
              :path (format nil "/~a.html" (post-slug post))
              :buffer (format nil "~a.md" (post-slug post)) :mode "Markdown")
    (:a.back :href "/" (site :back-text))
    (:article
     (:p.post-meta (:time :datetime (post-date post) (post-date post)))
     (:h1 (post-title post))
     (:raw (post-html post)))))

(in-package #:blog)

(defvar *site* nil
  "Plist read from site.lisp.")

(defun site (key)
  (getf *site* key))

(defun absolute-url (path)
  (concatenate 'string (string-right-trim "/" (site :url)) path))

(defmacro with-page ((&key title description path) &body body)
  "Render a full HTML page around BODY."
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
       (:main ,@body)
       (:script :type "module" :src "/assets/js/main.js")
       (let ((code (site :goatcounter)))
         (when code
           (:script :data-goatcounter
                    (format nil "https://~a.goatcounter.com/count" code)
                    :async t :src "//gc.zgo.at/count.js")))))))

(defun post-url (post)
  (format nil "/~a.html" (post-slug post)))

;; The home page reads like dired: each section a subdirectory listing.
(defun post-list (posts)
  (spinneret:with-html
    (:ul
     (dolist (post posts)
       (:li.line (:time :datetime (post-date post) (post-date post))
                 (:a :href (post-url post) (post-title post)))))))

;; Item names are padded to one width so the values line up.
;; Dispatch happens outside with-html: inside it, (:section ...) and friends
;; would be read as tags, even as case keys.
(defun home-entry (entry width)
  (destructuring-bind (kind label &optional value) entry
    (ecase kind
      (:item (spinneret:with-html
               (:li.line (:span.name (format nil "~va" width label))
                         (:span.value value))))
      (:link (spinneret:with-html
               (:li.line (:a :href value label)
                         (:span.target "-> " (remove-scheme value))))))))

(defun remove-scheme (url)
  (let ((start (search "://" url)))
    (if start (subseq url (+ start 3)) url)))

(defun home-section (section posts)
  (destructuring-bind (kind title &rest entries) section
    (ecase kind
      (:posts (spinneret:with-html
                (:section.dired (:h2 (format nil "~~/~a:" title))
                                (post-list posts))))
      (:section
       (let ((width (1+ (reduce #'max entries
                                :key (lambda (entry)
                                       (if (eq (first entry) :item)
                                           (length (second entry))
                                           0))
                                :initial-value 0))))
         (spinneret:with-html
           (:section.dired (:h2 (format nil "~~/~a:" title))
                           (:ul (dolist (entry entries)
                                  (home-entry entry width))))))))))

(defun home-page (posts)
  (with-page (:title (site :title) :description (site :description) :path "/")
    (:h1 (site :title))
    (dolist (section (site :home))
      (home-section section posts))))

(defun post-page (post)
  (with-page (:title (post-title post) :description (post-description post)
              :path (post-url post))
    (:a.back :href "/" (site :back-text))
    (:article
     (:p.post-meta (:time :datetime (post-date post) (post-date post)))
     (:h1 (post-title post))
     (:raw (post-html post)))))

;;; blog.el --- Static site generator for guiyuanju.github.io  -*- lexical-binding: t; -*-

;; `blog-build' turns posts/*.md and site.el into docs/, which GitHub Pages
;; serves from main; `blog-publish' builds, commits and pushes.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'url-util)

(defvar blog-root (file-name-directory (or load-file-name buffer-file-name))
  "Root of the blog repository.")

(defvar blog-required-pages
  '("index.html" "feed.xml"
    "crafting-interpreters.html"
    "expression-problem.html"
    "generic-vector-in-c.html"
    "implementing-a-hashtable-in-rust.html"
    "lambda-calculus-interpreter.html"
    "leetcode-24-swap-nodes-in-pairs.html"
    "leetcode-496-next-greater-element-i.html"
    "python-default-parameters.html"
    "swiftui-changes-to-unused-state-variables-in-the-body-may-be-ignored.html")
  "Pages the old Jekyll site served; the build fails if one goes missing.")

(defvar blog-code-modes
  '(("c" c-ts-mode c-mode)
    ("go" go-ts-mode go-mode)
    ("rust" rust-ts-mode rust-mode)
    ("python" python-ts-mode python-mode)
    ("swift" swift-mode)
    ("lisp" lisp-mode)
    ("elisp" emacs-lisp-mode)
    ("bash" bash-ts-mode sh-mode)
    ("sh" bash-ts-mode sh-mode))
  "Code block language to candidate major modes, best first.")

(defvar blog--site nil
  "Plist read from site.el.")

(defvar blog--css nil
  "Contents of style.css, inlined into every page.")

(defvar blog--icon nil
  "static/logo.png as a data URI.")

;;;; HTML

(defun blog--escape (string)
  (replace-regexp-in-string
   "[&<>\"]"
   (lambda (c) (pcase c ("&" "&amp;") ("<" "&lt;") (">" "&gt;") ("\"" "&quot;")))
   string t t))

(defconst blog--void-tags '(meta link img br hr))

(defun blog--html (node)
  "Render NODE: a string (escaped), (raw STRING), a list of nodes, or
\(TAG ATTRS . CHILDREN) with ATTRS an alist."
  (cond
   ((null node) "")
   ((stringp node) (blog--escape node))
   ((eq (car node) 'raw) (cadr node))
   ((not (symbolp (car node))) (mapconcat #'blog--html node ""))
   (t
    (pcase-let ((`(,tag ,attrs . ,children) node))
      (concat
       "<" (symbol-name tag)
       (mapconcat (lambda (attr)
                    (when (cdr attr)
                      (format " %s=\"%s\"" (car attr) (blog--escape (cdr attr)))))
                  attrs "")
       ">"
       (unless (memq tag blog--void-tags)
         (concat (mapconcat #'blog--html children "")
                 "</" (symbol-name tag) ">")))))))

;;;; Markdown: the subset the posts use

(defun blog--inline (text)
  "Render inline Markdown in TEXT to HTML."
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (let (out)
      (while (not (eobp))
        (push (blog--inline-token) out))
      (apply #'concat (nreverse out)))))

(defconst blog--link-target "(\\(?:<\\([^>]*\\)>\\|\\([^) \n]*\\)\\))"
  "A link destination, plain or in angle brackets.")

(defun blog--inline-token ()
  "Render the inline element at point as HTML and move past it."
  (cond
   ((looking-at "\\\\\\([[:punct:]]\\)")
    (goto-char (match-end 0))
    (blog--escape (match-string 1)))
   ((looking-at "`+")
    (let ((ticks (match-string 0))
          (start (match-end 0)))
      (goto-char start)
      (if (search-forward ticks nil t)
          (format "<code>%s</code>"
                  (blog--escape (string-trim (buffer-substring start (match-beginning 0)))))
        (blog--escape ticks))))
   ((looking-at (concat "!\\[\\([^]]*\\)\\]" blog--link-target))
    (goto-char (match-end 0))
    (let* ((src (or (match-string 2) (match-string 3)))
           (alt (match-string 1))
           (size (blog--image-size src)))
      (blog--html `(img ((src . ,src) (alt . ,alt)
                         (width . ,(car size)) (height . ,(cadr size))
                         (loading . "lazy"))))))
   ((looking-at (concat "\\[\\([^]]*\\)\\]" blog--link-target))
    (let ((href (or (match-string 2) (match-string 3)))
          (label (match-string 1)))
      (goto-char (match-end 0))
      (format "<a href=\"%s\">%s</a>" (blog--escape href) (blog--inline label))))
   ((looking-at "<\\(https?://[^>]+\\)>")
    (goto-char (match-end 0))
    (blog--html `(a ((href . ,(match-string 1))) ,(match-string 1))))
   ((looking-at "</?[A-Za-z][A-Za-z0-9-]*\\(?:\\s-[^>]*\\)?/?>")
    (goto-char (match-end 0))
    (match-string 0))
   ((looking-at "\\(\\*\\*\\|__\\)\\([^ \n]\\(?:.\\|\n\\)*?\\)\\1")
    (goto-char (match-end 0))
    (format "<strong>%s</strong>" (blog--inline (match-string 2))))
   ((and (looking-at "\\([*_]\\)\\([^ \n*_]\\(?:[^\n]*?[^ \n]\\)?\\)\\1")
         ;; Underscores inside words, as in snake_case, are not emphasis.
         (or (equal (match-string 1) "*")
             (not (or (memq (char-syntax (or (char-before) ?\s)) '(?w))
                      (memq (char-syntax (or (char-after (match-end 0)) ?\s)) '(?w))))))
    (goto-char (match-end 0))
    (format "<em>%s</em>" (blog--inline (match-string 2))))
   (t
    (forward-char 1)
    (blog--escape (string (char-before))))))

(defconst blog--list-marker "^\\( *\\)\\([-*+]\\|[0-9]+[.)]\\)\\( +\\)\\(.*\\)$")

(defun blog--block-start-p (line)
  "Non-nil if LINE starts a block that ends a paragraph."
  (string-match-p "^ *\\(```\\|#\\{1,6\\} \\|>\\|---+ *$\\|[-*+] \\|[0-9]+[.)] \\)" line))

(defun blog--markdown (text)
  "Render Markdown TEXT to HTML."
  (blog--blocks (split-string text "\n")))

(defun blog--blocks (lines &optional tight)
  "Render block-level Markdown LINES.  With TIGHT, paragraphs lose their <p>."
  (let ((v (vconcat lines))
        (i 0)
        out)
    (cl-flet ((line (n) (and (< n (length v)) (aref v n))))
      (while (< i (length v))
        (let ((l (aref v i)))
          (cond
           ((string-blank-p l) (cl-incf i))
           ;; Fenced code.
           ((string-match "^ *```\\(.*\\)$" l)
            (let ((lang (string-trim (match-string 1 l)))
                  code)
              (cl-incf i)
              (while (and (line i) (not (string-match-p "^ *``` *$" (line i))))
                (push (line i) code)
                (cl-incf i))
              (cl-incf i)
              (push (blog--code-block (string-join (nreverse code) "\n") lang) out)))
           ((string-match "^\\(#\\{1,6\\}\\) +\\(.*?\\)[ #]*$" l)
            (let ((tag (format "h%d" (length (match-string 1 l)))))
              (push (format "<%s>%s</%s>" tag (blog--inline (match-string 2 l)) tag) out)
              (cl-incf i)))
           ((string-match-p "^ *\\(---+\\|\\*\\*\\*+\\|___+\\) *$" l)
            (push "<hr>" out)
            (cl-incf i))
           ((string-match-p "^ *>" l)
            (let (quoted)
              (while (and (line i) (string-match "^ *> ?\\(.*\\)$" (line i)))
                (push (match-string 1 (line i)) quoted)
                (cl-incf i))
              (push (format "<blockquote>%s</blockquote>"
                            (blog--blocks (nreverse quoted)))
                    out)))
           ((and (string-match-p "^ *|" l)
                 (line (1+ i))
                 (string-match-p "^ *|?[ :|-]*-[ :|-]*$" (line (1+ i))))
            (let ((head (blog--table-cells l))
                  rows)
              (cl-incf i 2)
              (while (and (line i) (string-match-p "^ *|" (line i)))
                (push (blog--table-cells (line i)) rows)
                (cl-incf i))
              (push (blog--table head (nreverse rows)) out)))
           ((string-match blog--list-marker l)
            (setq i (blog--list v i (lambda (html) (push html out)))))
           ;; HTML block, passed through until a blank line.
           ((string-match-p "^<[A-Za-z/]" l)
            (let (html)
              (while (and (line i) (not (string-blank-p (line i))))
                (push (line i) html)
                (cl-incf i))
              (push (string-join (nreverse html) "\n") out)))
           (t
            (let (para)
              (while (and (line i)
                          (not (string-blank-p (line i)))
                          (or (null para) (not (blog--block-start-p (line i)))))
                (push (string-trim (line i)) para)
                (cl-incf i))
              (let ((html (blog--inline (string-join (nreverse para) "\n"))))
                (push (if tight html (format "<p>%s</p>" html)) out))))))))
    (string-join (nreverse out) "\n")))

(defun blog--list (v i emit)
  "Render the list starting at line I of V, pass its HTML to EMIT.
Return the index of the first line after the list."
  (let* ((first (aref v i))
         (ordered (progn (string-match blog--list-marker first)
                         (string-match-p "[0-9]" (match-string 2 first))))
         (start (and ordered (string-to-number (match-string 2 first))))
         (loose nil)
         items)
    (cl-flet ((line (n) (and (< n (length v)) (aref v n)))
              (same-kind-p (l) (and (string-match blog--list-marker l)
                                    (eq (and (string-match-p "[0-9]" (match-string 2 l)) t)
                                        (and ordered t)))))
      (while (and (line i) (same-kind-p (line i)))
        (string-match blog--list-marker (line i))
        (let* ((l (line i))
               (indent (+ (length (match-string 1 l)) (length (match-string 2 l))
                          (length (match-string 3 l))))
               (item (list (match-string 4 l))))
          (cl-incf i)
          (catch 'done
            (while (line i)
              (let ((l (line i)))
                (cond
                 ((string-blank-p l)
                  (let ((next (cl-loop for n from i
                                       while (and (line n) (string-blank-p (line n)))
                                       finally return (line n))))
                    (cond
                     ((and next (string-match-p (format "^ \\{%d\\}" indent) next))
                      (setq loose t)
                      (push "" item)
                      (cl-incf i))
                     ((and next (same-kind-p next))
                      (setq loose t)
                      (throw 'done nil))
                     (t (throw 'done nil)))))
                 ((string-match-p blog--list-marker l)
                  (if (string-match-p (format "^ \\{%d\\}" indent) l)
                      (progn (push (substring l indent) item) (cl-incf i))
                    (throw 'done nil)))
                 ((string-match-p (format "^ \\{%d\\}" indent) l)
                  (push (substring l indent) item)
                  (cl-incf i))
                 ((and (not (string-blank-p (car item))) (not (blog--block-start-p l)))
                  (push (string-trim l) item)
                  (cl-incf i))
                 (t (throw 'done nil))))))
          (push (nreverse item) items)
          (while (and (line i) (string-blank-p (line i))
                      (line (1+ i)) (same-kind-p (line (1+ i))))
            (cl-incf i))))
      (funcall emit
               (concat (if ordered
                           (if (and start (/= start 1)) (format "<ol start=\"%d\">" start) "<ol>")
                         "<ul>")
                       (mapconcat (lambda (item)
                                    (format "<li>%s</li>" (blog--blocks item (not loose))))
                                  (nreverse items) "")
                       (if ordered "</ol>" "</ul>")))
      i)))

(defun blog--table-cells (line)
  (mapcar (lambda (cell) (blog--inline (string-trim cell)))
          (split-string (string-trim (string-trim line) "|" "|") "|")))

(defun blog--table (head rows)
  (cl-flet ((row (tag cells)
              (concat "<tr>"
                      (mapconcat (lambda (c) (format "<%s>%s</%s>" tag c tag)) cells "")
                      "</tr>")))
    (concat "<table><thead>" (row "th" head) "</thead><tbody>"
            (mapconcat (lambda (cells) (row "td" cells)) rows "")
            "</tbody></table>")))

;;;; Images

(defun blog--webp-size (file)
  "Width and height of the WebP FILE as strings, or nil."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file nil 0 30)
    (cl-flet ((b (n) (char-after (1+ n))))
      (mapcar
       #'number-to-string
       (pcase (buffer-substring 13 17)
         ("VP8L" (list (1+ (logior (b 21) (ash (logand (b 22) #x3f) 8)))
                       (1+ (logior (ash (b 22) -6) (ash (b 23) 2)
                                   (ash (logand (b 24) #xf) 10)))))
         ("VP8X" (list (1+ (logior (b 24) (ash (b 25) 8) (ash (b 26) 16)))
                       (1+ (logior (b 27) (ash (b 28) 8) (ash (b 29) 16)))))
         ("VP8 " (list (logand (logior (b 26) (ash (b 27) 8)) #x3fff)
                       (logand (logior (b 28) (ash (b 29) 8)) #x3fff))))))))

(defun blog--image-size (src)
  "Width and height of the image at SRC if it is a WebP file in static/."
  (let ((file (expand-file-name (concat "static" src) blog-root)))
    (when (and (string-prefix-p "/" src) (string-suffix-p ".webp" src)
               (file-regular-p file))
      (blog--webp-size file))))

;;;; Code highlighting with font-lock

(defun blog--code-mode (lang)
  "The first usable major mode for LANG, or nil."
  (cl-find-if (lambda (mode)
                (and (fboundp mode)
                     (let ((name (symbol-name mode)))
                       (or (not (string-suffix-p "-ts-mode" name))
                           (and (fboundp 'treesit-language-available-p)
                                (treesit-language-available-p
                                 (intern (string-remove-suffix "-ts-mode" name))))))))
              (cdr (assoc lang blog-code-modes))))

(defun blog--face-class (face)
  "The font-lock face FACE is or inherits from, as a class name."
  (let ((face (if (consp face) (car face) face)))
    (when (and face (symbolp face) (facep face))
      (let ((name (symbol-name face)))
        (if (string-prefix-p "font-lock-" name)
            (string-remove-suffix "-face" name)
          (let ((parent (face-attribute face :inherit nil)))
            (unless (eq parent 'unspecified)
              (blog--face-class parent))))))))

(defun blog--styled-class (face)
  "The class for FACE if style.css colors it, else nil."
  (let ((class (blog--face-class face)))
    (and class
         (string-match-p (concat "\\." (regexp-quote class) "[^a-z-]") blog--css)
         class)))

(defun blog--fontify (code mode)
  "CODE as HTML, each face run a <span> classed by its font-lock face."
  (with-temp-buffer
    (insert code)
    ;; Mode hooks would start the user's LSP clients and the like.
    (delay-mode-hooks (funcall mode))
    (font-lock-ensure)
    (let ((pos (point-min))
          out)
      (while (< pos (point-max))
        (let ((class (blog--styled-class (get-text-property pos 'face)))
              (next pos))
          ;; Neighboring faces that end up with the same class share one span.
          (while (and (< next (point-max))
                      (equal class (blog--styled-class (get-text-property next 'face))))
            (setq next (next-single-property-change next 'face nil (point-max))))
          (let ((text (blog--escape (buffer-substring-no-properties pos next))))
            (push (if class (format "<span class=\"%s\">%s</span>" class text) text)
                  out))
          (setq pos next)))
      (apply #'concat (nreverse out)))))

(defun blog--code-block (code lang)
  (let* ((lang (unless (string-empty-p lang) lang))
         (mode (and lang (blog--code-mode lang))))
    (format "<pre%s><code>%s</code></pre>"
            (if lang (format " data-lang=\"%s\"" (blog--escape lang)) "")
            (if mode (blog--fontify code mode) (blog--escape code)))))

;;;; Posts

(defun blog--site (key)
  (plist-get blog--site key))

(defun blog--read-file (file)
  "Return the first form in FILE and the text after it."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents file))
    (goto-char (point-min))
    (cons (read (current-buffer))
          (buffer-substring-no-properties (point) (point-max)))))

(defun blog--filename-slug (file)
  "2025-12-24-Lambda-Calculus.md => \"lambda-calculus\"."
  (let ((name (file-name-base file)))
    (downcase (if (string-match "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}-" name)
                  (substring name (match-end 0))
                name))))

(defun blog--read-post (file)
  (pcase-let ((`(,header . ,body) (blog--read-file file)))
    (unless (and (plist-get header :title) (plist-get header :date))
      (error "%s: header needs :title and :date" file))
    (append (list :slug (or (plist-get header :slug) (blog--filename-slug file))
                  :html (blog--markdown body))
            header)))

(defun blog--read-posts ()
  (sort (cl-remove-if (lambda (post) (plist-get post :draft))
                      (mapcar #'blog--read-post
                              (directory-files (expand-file-name "posts" blog-root)
                                               t "\\.md\\'")))
        (lambda (a b) (string> (plist-get a :date) (plist-get b :date)))))

(defun blog--post-url (post)
  (format "/%s.html" (plist-get post :slug)))

;;;; Pages

(defun blog--absolute-url (path)
  (concat (string-remove-suffix "/" (blog--site :url)) path))

(defun blog--page (title description path body)
  (concat
   "<!DOCTYPE html>\n"
   (blog--html
    `(html ((lang . "en"))
           (head ()
                 (meta ((charset . "utf-8")))
                 (meta ((name . "viewport") (content . "width=device-width, initial-scale=1")))
                 (title () ,title)
                 ,(when description
                    `((meta ((name . "description") (content . ,description)))
                      (meta ((property . "og:description") (content . ,description)))))
                 (meta ((property . "og:title") (content . ,title)))
                 (meta ((property . "og:url") (content . ,(blog--absolute-url path))))
                 (link ((rel . "canonical") (href . ,(blog--absolute-url path))))
                 (link ((rel . "alternate") (type . "application/atom+xml")
                        (title . ,(blog--site :title)) (href . "/feed.xml")))
                 (link ((rel . "icon") (href . ,blog--icon)))
                 (style () (raw ,blog--css)))
           (body ()
                 (main () ,@body)
                 ,(when-let* ((code (blog--site :goatcounter)))
                    `(script ((data-goatcounter . ,(format "https://%s.goatcounter.com/count" code))
                              (async . "") (src . "//gc.zgo.at/count.js")))))))
   "\n"))

(defun blog--remove-scheme (url)
  (replace-regexp-in-string "\\`[a-z]+://" "" url))

(defun blog--home-section (section posts)
  "The home page reads like dired: each section a subdirectory listing."
  (pcase-let* ((`(,kind ,title . ,entries) section)
               ;; Item names are padded to one width so the values line up.
               (width (1+ (apply #'max 0 (mapcar (lambda (e)
                                                   (if (eq (car e) :item) (length (cadr e)) 0))
                                                 entries)))))
    `(section ((class . "dired"))
              (h2 () ,(format "~/%s:" title))
              (ul ()
                  ,@(pcase kind
                      (:posts
                       (mapcar (lambda (post)
                                 `(li ((class . "line"))
                                      (time ((datetime . ,(plist-get post :date)))
                                            ,(plist-get post :date))
                                      (a ((href . ,(blog--post-url post)))
                                         ,(plist-get post :title))))
                               posts))
                      (:section
                       (mapcar (lambda (entry)
                                 (pcase entry
                                   (`(:item ,name ,value)
                                    `(li ((class . "line"))
                                         (span ((class . "name")) ,(string-pad name width))
                                         (span ((class . "value")) ,value)))
                                   (`(:link ,name ,url)
                                    `(li ((class . "line"))
                                         (a ((href . ,url)) ,name)
                                         (span ((class . "target"))
                                               ,(concat "-> " (blog--remove-scheme url)))))))
                               entries)))))))

(defun blog--home-page (posts)
  (blog--page (blog--site :title) (blog--site :description) "/"
              `((h1 () ,(blog--site :title))
                ,@(mapcar (lambda (section) (blog--home-section section posts))
                          (blog--site :home)))))

(defun blog--post-page (post)
  (blog--page (plist-get post :title) (plist-get post :description) (blog--post-url post)
              `((a ((class . "back") (href . "/")) ,(blog--site :back-text))
                (article ()
                         (p ((class . "post-meta"))
                            (time ((datetime . ,(plist-get post :date)))
                                  ,(plist-get post :date))
                            (span ((class . "print-only"))
                                  ,(format " · %s · %s" (blog--site :author)
                                           (blog--absolute-url (blog--post-url post)))))
                         (h1 () ,(plist-get post :title))
                         (raw ,(plist-get post :html))))))

(defun blog--feed (posts)
  (let ((time (lambda (date) (format "%sT00:00:00%s" date (blog--site :timezone)))))
    (concat
     "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
     "<feed xmlns=\"http://www.w3.org/2005/Atom\">\n"
     (format "<title>%s</title>\n" (blog--escape (blog--site :title)))
     (format "<link href=\"%s\" rel=\"self\"/>\n" (blog--absolute-url "/feed.xml"))
     (format "<link href=\"%s\"/>\n" (blog--absolute-url "/"))
     (format "<id>%s</id>\n" (blog--absolute-url "/"))
     (format "<updated>%s</updated>\n"
             (funcall time (if posts (plist-get (car posts) :date) "1970-01-01")))
     (format "<author><name>%s</name></author>\n" (blog--escape (blog--site :author)))
     (mapconcat
      (lambda (post)
        (let ((url (blog--absolute-url (blog--post-url post))))
          (format "<entry>\n<title>%s</title>\n<link href=\"%s\"/>\n<id>%s</id>\n<updated>%s</updated>\n<content type=\"html\">%s</content>\n</entry>\n"
                  (blog--escape (plist-get post :title)) url url
                  (funcall time (plist-get post :date))
                  (blog--escape (plist-get post :html)))))
      posts "")
     "</feed>\n")))

;;;; Build and publish

(defun blog--write (out name content)
  (let ((file (expand-file-name name out))
        (coding-system-for-write 'utf-8-unix))
    (make-directory (file-name-directory file) t)
    (with-temp-file file (insert content))))

;;;###autoload
(defun blog-build ()
  "Generate the site into docs/, replacing it."
  (interactive)
  (let* ((blog--site (car (blog--read-file (expand-file-name "site.el" blog-root))))
         (blog--css (with-temp-buffer
                      (insert-file-contents (expand-file-name "style.css" blog-root))
                      (buffer-string)))
         (blog--icon (with-temp-buffer
                       (set-buffer-multibyte nil)
                       (insert-file-contents-literally
                        (expand-file-name "static/logo.png" blog-root))
                       (concat "data:image/png;base64,"
                               (base64-encode-string (buffer-string) t))))
         (posts (blog--read-posts))
         (out (expand-file-name "docs/" blog-root)))
    (when (file-directory-p out)
      (delete-directory out t))
    (copy-directory (expand-file-name "static/" blog-root) out nil t t)
    (blog--write out "index.html" (blog--home-page posts))
    (dolist (post posts)
      (blog--write out (concat (plist-get post :slug) ".html") (blog--post-page post)))
    (blog--write out "feed.xml" (blog--feed posts))
    ;; Without it GitHub Pages runs Jekyll over docs/.
    (blog--write out ".nojekyll" "")
    (when-let* ((missing (cl-remove-if (lambda (page) (file-exists-p (expand-file-name page out)))
                                       blog-required-pages)))
      (error "Missing pages: %s" (string-join missing ", ")))
    (message "Built %d posts into %s" (length posts) out)))

;;;; Preview

(defvar blog-preview-port 8000)

(defconst blog--content-types
  '(("html" . "text/html; charset=utf-8") ("css" . "text/css")
    ("xml" . "application/atom+xml") ("png" . "image/png")
    ("jpg" . "image/jpeg") ("webp" . "image/webp") ("svg" . "image/svg+xml")))

(defun blog--preview-filter (proc request)
  "Answer one GET REQUEST on PROC with a file from docs/."
  (let* ((path (and (string-match "\\`GET \\([^ ?#]*\\)" request)
                    (url-unhex-string (match-string 1 request))))
         (docs (expand-file-name "docs/" blog-root))
         (file (and path (expand-file-name (concat "." path) docs)))
         (file (if (and file (file-directory-p file)) (expand-file-name "index.html" file) file)))
    (if (and file (string-prefix-p docs file) (file-regular-p file))
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert-file-contents-literally file)
          (process-send-string
           proc (format "HTTP/1.0 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\n\r\n"
                        (or (cdr (assoc (file-name-extension file) blog--content-types))
                            "application/octet-stream")
                        (buffer-size)))
          (process-send-region proc (point-min) (point-max)))
      (process-send-string proc "HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n"))
    (process-send-eof proc)))

;;;###autoload
(defun blog-preview ()
  "Build the site and open it from a local server on `blog-preview-port'."
  (interactive)
  (blog-build)
  (unless (process-live-p (get-process "blog-preview"))
    (make-network-process :name "blog-preview" :server t :host 'local
                          :service blog-preview-port :coding 'binary :noquery t
                          :filter #'blog--preview-filter))
  (browse-url (format "http://localhost:%d/" blog-preview-port)))

;;;###autoload
(defun blog-preview-stop ()
  "Stop the server started by `blog-preview'."
  (interactive)
  (if-let* ((proc (get-process "blog-preview")))
      (progn (delete-process proc) (message "Blog preview stopped"))
    (message "Blog preview is not running")))

;;;###autoload
(defun blog-publish ()
  "Build the site, commit everything, and push."
  (interactive)
  (blog-build)
  (let ((default-directory blog-root))
    (compile "git add -A && { git diff --cached --quiet || git commit -m Publish; } && git push")))

(provide 'blog)
;;; blog.el ends here

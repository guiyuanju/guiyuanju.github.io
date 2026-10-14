(defsystem "blog"
  :description "Static site generator for guiyuanju.github.io."
  :depends-on ("3bmd" "3bmd-ext-code-blocks" "3bmd-ext-tables" "spinneret")
  :pathname "src/"
  :serial t
  :components ((:file "package")
               (:file "post")
               (:file "page")
               (:file "feed")
               (:file "build")))

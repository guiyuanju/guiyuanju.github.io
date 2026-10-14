# guiyuanju.github.io

Blog built by a small Common Lisp static site generator (SBCL, 3bmd, spinneret).

- `posts/YYYY-MM-DD-slug.md`: a header form `(:title "..." :date "YYYY-MM-DD")`, then Markdown. Optional `:slug`, `:description`, `:draft t`.
- `site.lisp`: site settings and the home page sections.
- `static/`: copied to the site root as is.
- `src/`: the generator.

Build into `_site/` and preview (needs Quicklisp in `~/quicklisp`):

```sh
sbcl --non-interactive --load make.lisp
./check.sh
python3 -m http.server -d _site
```

Pushing to `main` builds and deploys to GitHub Pages via `.github/workflows/deploy.yml`.

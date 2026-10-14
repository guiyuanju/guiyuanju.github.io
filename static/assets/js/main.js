import hljs from "./hljs/core.min.js";
import bash from "./hljs/languages/bash.min.js";
import c from "./hljs/languages/c.min.js";
import go from "./hljs/languages/go.min.js";
import lisp from "./hljs/languages/lisp.min.js";
import python from "./hljs/languages/python.min.js";
import rust from "./hljs/languages/rust.min.js";
import swift from "./hljs/languages/swift.min.js";

for (const [name, lang] of Object.entries({ bash, c, go, lisp, python, rust, swift })) {
  hljs.registerLanguage(name, lang);
}
hljs.highlightAll();

#!/bin/sh
# Fails the build if a URL the old Jekyll site served is missing from _site/.
cd "$(dirname "$0")/_site" || exit 1
status=0
for page in index.html feed.xml \
  crafting-interpreters.html \
  expression-problem.html \
  generic-vector-in-c.html \
  implementing-a-hashtable-in-rust.html \
  lambda-calculus-interpreter.html \
  leetcode-24-swap-nodes-in-pairs.html \
  leetcode-496-next-greater-element-i.html \
  python-default-parameters.html \
  swiftui-changes-to-unused-state-variables-in-the-body-may-be-ignored.html
do
  [ -f "$page" ] || { echo "missing: /$page"; status=1; }
done
exit $status

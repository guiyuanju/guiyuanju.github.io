(:title "Default Parameters in Python"
 :date "2024-06-20")

Consider the following class:

```python
class LineCollector:
    def __init__(self, lines=[]):
        self.lines = lines

    def collect(self, line):
        self.lines.append(line)

c1 = LineCollector()
c2 = LineCollector()

c1.collect("Hi mom")
c2.collect("Are you ok Annie?")

print(c1.lines)
```

What output would you expect?

The result is:

```python
['Hi mom', 'Are you ok Annie?']
```

Surprising right? As a programmer who are new to Python, I am very confused by this behavior. The mechanism behind it is:

1. Python evaluate the default value only once when it come across the def statement
2. Every subsequent call uses the same pre-evaluated default object.

Someone mentioned that this behavior can actually be useful for capturing a variable’s value inside a loop:

```python
fs = []
for i in range(10):
    def f():
        print(i)
    fs.append(f)

[f() for f in fs]
```

It prints out 10 ‘9’s, with this feature, the following program print 0 to 9 correctly:

```python
fs = []
for i in range(10):
    def f(i=i):
        print(i)
    fs.append(f)

[f() for f in fs]
```

Alternatively, we can use a closure like this, though it’s a bit more complex:

```python
fs = []
for i in range(10):
    def f(i):
        return lambda: (print(i))
    fs.append(f(i))

[f() for f in fs]
```

This problem actually reminds me of the similar for loop variable capture problem in Go, which is fixed in Go 1.22 https://go.dev/blog/loopvar-preview

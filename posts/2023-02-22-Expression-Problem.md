(:title "Expression Problem"
 :date "2023-02-22")

OOP (Object-Oriented Programming) and FP (Functional Programming) are two prominent programming paradigms today, each offering distinct advantages and facing unique challenges. A classical example illustrating their differences is the expression problem.

The **expression problem** is concerned with extensibility regarding operations and types. Consider a type called number, which has two subtypes: int and float, along with two operations: + and -. This can be represented in a table of implementations:

| Operation / Type | `int` | `float` |
| ---------------- | ----- | ------- |
| `+`              | ...   | ...     |
| `-`              | ...   | ...     |

**OOP Perspective**

In an OOP language like Java, number is defined as an interface with methods for + and -. The int and float types are classes implementing this interface. Adding a new subtype, such as a complex class representing complex numbers, is straightforward. You simply create the new class and implement the necessary methods without altering the existing code for int and float, thus avoiding recompilation.

However, adding a new operation, like _ (multiply), becomes challenging. You must locate the code for int, float, and complex, add the _ method, and recompile all affected classes. This process can be time-consuming and error-prone.

**FP Perspective**

In an FP language like Haskell, number is a user-defined union type with constructors for int and float. Operations like + and - are defined as functions using case structures to handle each type variant. Adding a new operation, such as \*, is simple; you just define a new function without modifying the type definition.

However, introducing a new type variant, like complex, requires modifying all functions defined on the number type, which can be cumbersome.

**Complementary Strengths and Weaknesses**

From this discussion, we see that OOP and FP have complementary strengths and weaknesses. OOP focuses on grouping operations into classes, making it easy to add new classes, while FP groups operations into functions, facilitating the addition of new operations.

When modeling real-world problems, which often evolve, it can be challenging to anticipate future needs. Is there a way to achieve extensibility for both operations and types? Yes, several methods exist:

1. **Multiple Dispatch**

Multiple dispatch (or multi-methods) dispatches function implementations based on all of their arguments, unlike the single dispatch common in OOP languages like Java, which determines method implementation based solely on the receiver. Multiple dispatch is open, allowing users to extend existing multi-methods from third-party packages without modifying them. Adding an operation requires defining multiple multi-methods for existing types, while adding a new type necessitates creating multi-methods for both the new type and existing types. CLOS (Common Lisp Object System) is a well-known example of multiple dispatch.

2. **Open Classes**

Open classes, often found in dynamic languages like Ruby, allow users to dynamically add methods to existing classes without modifying the original code. This flexibility enhances extensibility.

3. **Type Classes**

Haskell employs type classes to address the expression problem. A type class defines the necessary "abstract" or "virtual" methods required for any type belonging to that class. Operations are defined based on these abstractions. Adding a new type simply involves implementing the required abstractions for the type class, allowing existing operations to remain unchanged.

**Observer Pattern**

Notably, the **observer pattern** is a design pattern that shifts a program's focus from types to operations. This transition allows for the exchange of advantages and disadvantages between OOP and FP, but it does not resolve the expression problem; rather, it transitions the problem from the OOP side to the FP side.

In summary, while OOP and FP each have their strengths and weaknesses regarding extensibility, various techniques can help achieve a balance, allowing for both operations and types to be extended more easily.

**References**

1. [The Expression Problem in Wikipedia](https://en.wikipedia.org/wiki/Expression_problem)
2. [Object-Oriented Programming Versus Abstract Data Types](https://www.cs.utexas.edu/users/wcook/papers/OOPvsADT/CookOOPvsADT90.pdf)

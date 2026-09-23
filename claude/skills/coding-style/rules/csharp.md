# Coding style: C#

These apply on top of the any-language preferences.

## Member ordering

- Order members within a class: constants, then `private readonly` dependency fields, then the constructor, then properties, then methods
- Methods read top-down. A public method comes before the private helpers it calls, so the class descends from what it does to how it does it
- A helper used by several methods goes after the last of them, or at the bottom of the class with the other shared helpers. Never declare a helper above its caller
- `static` does not affect placement. It marks a helper that touches no dependencies, and is not a grouping key: don't hoist static helpers into a block of their own

## Comments

- Don't put XML doc comments (`///`) on methods. The name and signature carry the contract, and a `<summary>` that restates them is noise
- A method earns `///` only on a public API surface consumed outside the solution, or where a `<param>`, `<returns>` or `<exception>` records a constraint the signature cannot express. A non-obvious _why_ still belongs in a `//` note
- Prefer `///` over `//` when documenting properties or fields, because it surfaces in IntelliSense. That preference is about properties and fields only, and is not a reason to document a method

## Error handling

- Prefer `catch (SpecificException e) when (<filter>)` over a broad catch, so unrelated failures are never intercepted

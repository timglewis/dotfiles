# Coding style: C#

These apply on top of the any-language preferences.

## Comments

- Don't put XML doc comments (`///`) on methods. The name and signature carry the contract, and a `<summary>` that restates them is noise
- A method earns `///` only on a public API surface consumed outside the solution, or where a `<param>`, `<returns>` or `<exception>` records a constraint the signature cannot express. A non-obvious _why_ still belongs in a `//` note
- Prefer `///` over `//` when documenting properties or fields, because it surfaces in IntelliSense. That preference is about properties and fields only, and is not a reason to document a method

## Error handling

- Prefer `catch (SpecificException e) when (<filter>)` over a broad catch, so unrelated failures are never intercepted

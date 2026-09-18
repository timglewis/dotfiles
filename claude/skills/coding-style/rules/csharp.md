# Coding style: C#

These apply on top of the any-language preferences.

- Prefer XML doc comments (`///`) over `//` line comments when documenting properties or fields, because they surface in IntelliSense. Reserve `//` for inline notes on non-obvious logic
- Prefer `catch (SpecificException e) when (<filter>)` over a broad catch, so unrelated failures are never intercepted

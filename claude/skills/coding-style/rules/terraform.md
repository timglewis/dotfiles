# Coding style: Terraform

These apply on top of the any-language preferences.

- Split `resource` blocks into separate files by type: one file per logical resource group, so a reader can find a thing by its kind
- Group the root wiring (backend, providers, locals, data sources) into `main.tf`, in that order, when each part is small. Don't carve out a file to hold one local or a seven-line backend block
- No single-use modules. A module is a unit of reuse; if it has exactly one consumer, inline it into the root and delete the `modules/` tree. Don't copy the pattern from a reference repo just because it's there
- Never declare a `provider` block inside a module: it's deprecated, and it's a sign the module shouldn't exist
- When a refactor renames resource addresses, use `moved {}` blocks rather than `terraform state mv`: they're declarative, visible in the plan, reviewable in the PR, and applied by CI automatically. Delete them once every environment has applied
- Give every variable a `type`. Add a `description` only where the name doesn't already carry the meaning
- Verify a refactor with a plan showing `0 to add, 0 to destroy` before committing it

# Coding style: front-end

These apply on top of the any-language preferences, to code that ships to the browser.

## Backend detail

Front-end source is public. Source maps carry the original files, comments included, and
anyone can read them in the browser's dev tools. Treat the backend as a black box that the
front end knows only through its API contract.

- Never name backend internals in a comment: services, classes, tables, queues, stored
  procedures, infrastructure, hostnames, or how the server works out a result
- A comment may describe what the API promises (a field can be null, a list arrives
  unsorted), but not why the server behaves that way
- When a front-end workaround exists because of backend behaviour, describe the constraint
  as the client sees it. The backend reason goes in the commit message or the ticket, which
  stay private
- The same applies to string literals, console output and error messages. These survive
  minification even when comments do not

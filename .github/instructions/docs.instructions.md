---
description: "Use when writing or editing documentation in docs/. Covers the docs convention: non-plan docs must be readable in under 5 minutes from that doc alone; overflow detail goes to sub-docs."
name: "Docs convention"
applyTo: ["docs/**/*.md"]
---

# Documentation convention

- **Plans of action** (e.g. `docs/desktop-refactor-plan.md`) are exempt: they may be long and reference other files freely.
- **Any other doc** must be understandable from reading that doc alone, in under 5 minutes.
  - Lead with the essentials: what it is, where the code lives, minimum usage snippet.
  - Keep tables/lists short; no deep dives inline.
- **Overflow detail** goes into sub-docs under a folder named after the main doc (e.g. `docs/streaming.md` → `docs/streaming/host.md`, `docs/streaming/podman.md`). The main doc references each sub-doc in one short line ("Details: [link]").
- When documenting a NixOS module, state: module file path, module attr name, option namespace, a minimum enable snippet, and host usage — nothing more in the main doc.

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
- **Overflow detail** goes into sub-docs under a folder named after the main doc (e.g. `docs/streaming.md` → `docs/streaming/host.md`, `docs/streaming/podman.md`). The main doc references each sub-doc in one short line ("Details: [link]"). Chains may nest as deep as needed (`docs/x.md` → `docs/x/y.md` → `docs/x/y/z.md`); index docs just point down the chain.
- When documenting a NixOS module, state: module file path, module attr name, option namespace, a minimum enable snippet, and host usage — nothing more in the main doc.
- **Leaf docs** (the end of a chain) carry the depth: they explain *how* the subsystem works AND *why* it works — why each specific setting, default, override, or architectural choice is set the way it is (non-default values, `mkForce`s, assertions, shutdown tricks, security modes, etc.). Pull the rationale from the code's own comments where they exist; never just restate what the code says.
- Never document secret *values* — secret names, file paths, and how they are consumed are fine.

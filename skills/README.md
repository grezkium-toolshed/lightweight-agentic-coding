# Curated Skills

> **Warning:** Do NOT add skills here. This directory is a maintainers' index only. Add new skills to `.opencode/skills/<name>/SKILL.md` for runtime discovery.

This repo provides project-local OpenCode skills under `.opencode/skills/`.
Pack metadata and scenario mapping live in `catalog/workflow-packs.json` and `catalog/scenarios.json`.

The `skills/` directory is the maintainers' index; the runtime-discoverable files live in `.opencode/skills/*/SKILL.md`.

Contract:
- Do not treat `skills/` as a runtime load path.
- Keep canonical runnable skill files in `.opencode/skills/*/SKILL.md`.

Naming overlap policy:
- Some skill names intentionally match agent names (for example `documentation-generator`, `research-synthesizer`).
- Matching names are allowed and expected when an agent orchestrates work and a skill provides the reusable execution contract.
- If both exist, treat the skill as capability-level instructions and the agent as coordination logic.

Required SKILL.md contract:
- Frontmatter keys: `name`, `description`, `license`, `compatibility`, `metadata.audience`, `metadata.output`, `metadata.workflow`.
- Required sections: `What I do`, `When to use me`, `Workflow`, `Guardrails`, `Notes`.

## Skill Index

| Skill | Description | Audience | Output |
|---|---|---|---|
| `docx-workflow` | Create or revise .docx documents using reproducible local tooling | office | docx |
| `pptx-workflow` | Build or revise PowerPoint decks with a clear slide structure and speaker intent | office | pptx |
| `xlsx-workflow` | Create or revise spreadsheets with formulas, structure, and validation notes | office | xlsx |
| `pdf-workflow` | Generate, inspect, or revise PDFs where layout and extractability matter | office | pdf |
| `documentation-generator` | Draft practical setup, rollout, and usage documentation from repository reality | maintainers | markdown-docs |
| `research-synthesizer` | Turn scattered model, provider, and tooling research into concise recommendations | maintainers | recommendation-doc |
| `gsd` | Structured Discuss → Plan → Execute → Verify → Ship workflow to prevent context rot in multi-session work | maintainers | execution-plan-and-status |
| `agent-browser` | Browser automation CLI for AI agents. Use when the user needs to inspect, test, or automate browser behavior: navigating pages, filling forms, clicking buttons, taking screenshots, extracting page data, reading selected Open Design browser-tab context, testing web apps, dogfooding Open Design previews, QA, bug hunts, or reviewing app quality. | cross-functional | browser-automation |
| `algorithmic-art` | Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use this when users request creating art using code, generative art, algorithmic art, flow fields, or particle systems. | design | art |
| `article-magazine` | Huashu / huashu-md-html-inspired magazine article layout for turning Markdown or notes into a polished long-form HTML essay. | design | html |
| `brainstorming` | You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation. | maintainers | plan |
| `brand-guidelines` | Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic's look-and-feel. | design | design-system |
| `brandkit` | Premium brand-kit image generation skill for creating high-end brand-guidelines boards, logo systems, identity decks, and visual-world presentations. | design | image |
| `canvas-design` | Create beautiful visual art in .png and .pdf documents using design philosophy. | design | png-pdf |
| `card-twitter` | Twitter quote or data card designed to pair with a post. | design | image |
| `color-expert` | Use when working with color naming, color theory, color spaces, color definitions, or any task involving color knowledge - palettes, ramps, gradients, conversions, accessibility, perceptual matching, pigment mixing, print-vs-screen color, CSS color syntax, or historical color terminology. | design | reference |
| `competitive-ads-extractor` | Extracts and analyzes competitors' ads from ad libraries (Facebook, LinkedIn, etc.) to understand what messaging, problems, and creative approaches are working. Helps inspire and improve your own ad campaigns. | cross-functional | research |
| `copywriting` | When the user wants to write, rewrite, or improve marketing copy for any page — including homepage, landing pages, pricing pages, feature pages, about pages, or product pages. | cross-functional | copy |
| `creative-director` | AI creative director with recursive self-assessment. Generates concepts using world-class methodologies (SIT, TRIZ, Lateral Thinking, bisociation), scores against 6 weighted criteria with Cannes/D&AD/HumanKind calibration, and recursively refines until the 9+ threshold is reached. | design | creative-brief |
| `data-report` | Turns CSV, Excel, or JSON data into a polished visual report page. | design | html |
| `deck-open-slide-canvas` | Locked 1920x1080 canvas deck with React component-level free composition, not bound to a fixed template. | design | html |
| `deck-swiss-international` | 16-column grid, one saturated accent, and 22 locked layouts (Klein Blue, Lemon, Mint, Safety Orange). | design | html |
| `design-brief` | Parse a structured design brief written in I-Lang protocol format into a concrete design spec. Eliminates ambiguity from vague requests like "make it professional" by requiring explicit dimensions: palette, typography, layout, mood, density, and constraints. | design | design-spec |
| `design-consultation` | Design consultation: understands your product, researches the landscape, proposes a complete design system (aesthetic, typography, color, layout, spacing, motion), and generates font+color preview... (gstack) | design | design-system |
| `design-review` | Designer's eye QA: finds visual inconsistency, spacing issues, hierarchy problems, AI slop patterns, and slow interactions — then fixes them. (gstack) | design | audit |
| `doc-kami-parchment` | Warm parchment canvas (#f5f4ed), monochrome ink-blue accent (#1B365D), one serif family, and editorial-grade typography. | design | html |
| `faq-page` | A Frequently Asked Questions (FAQ) page with collapsible accordion sections, search functionality, and category filtering. Use when the brief asks for "FAQ", "help center", "questions", or "support page". | design | html |
| `gsap-core` | Official GSAP skill for the core API — gsap.to(), from(), fromTo(), easing, duration, stagger, defaults, gsap.matchMedia() (responsive, prefers-reduced-motion). Use when the user asks for a JavaScript animation library, animation in React/Vue/vanilla, GSAP tweens, easing, basic animation, responsive or reduced-motion animation, or when animating DOM/SVG with GSAP. | design | animation |
| `impeccable-design-polish` | Follow-up design polish skill inspired by Impeccable. Use after a web or HTML artifact exists to audit, critique, polish, animate, harden, and prepare the page for a live/share pass. | design | audit |
| `pdf` | Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs to make them searchable. | office | pdf |
| `ppt-keynote` | Apple Keynote-quality slides, one card per screen, with keyboard left/right navigation. | design | html |
| `pptx-html-fidelity-audit` | Audit a python-pptx export against its source HTML deck, identify layout/content drift (footer overflow, cropped content, missing italic/em, lost styling, off-rhythm spacing), and re-export with strict footer-rail + cursor-flow layout discipline. | engineering | pptx |
| `research-decision-room` | Turn messy user research notes, interviews, support tickets, surveys, and product context into an evidence-backed decision room: a single HTML artifact with an evidence ledger, theme map, confidence heatmap, opportunity matrix, decision memo, and experiment queue. | cross-functional | research-brief |
| `ui-ux-pro-max` | AI-powered design intelligence toolkit providing searchable databases of UI styles, color palettes, font pairings, chart types, and UX guidelines. | design | reference |

These skills make the cluster immediately useful for design, office, and documentation work, not only coding.

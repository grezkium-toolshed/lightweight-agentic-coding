---
name: AGENTS
description: Use when documenting agent conventions, build commands, and code style for the AI coding cluster
---

# AGENTS.md

## Overview
This document defines conventions for using AI agents in the OpenCode coding cluster. It covers build commands, code style guidelines, agent categories, and special considerations for AI-driven workflows.

## Build & Development
- **Build**: `npm run build`
- **Lint**: `npm run lint` (ESLint for JS/TS, Prettier for formatting)
- **Test**: `npm run test` (Jest for unit tests, Playwright for end-to-end)
- **Verify**: `npm run verify` (lsp_diagnostics + build)

## Code Style
- **Config files**: JSON/JSONC/YAML with 2-space indentation
- **Documentation**: Markdown with PascalCase headings
- **Naming**: Use `PascalCase` for files, `snake_case` for variables, `camelCase` for functions
- **Formatting**: Prettier for JS/TS, Black for Python, JSONC for config files

## Agent Categories
- **Explore**: For research and discovery tasks
- **Librarian**: For code and documentation queries
- **Oracle**: For code analysis and suggestions
- **Hephaestus**: For code generation and implementation
- **Metis**: For architectural decisions
- **Mimus**: For quick checks and simple tasks
- **Multimodal-Looker**: For analyzing media files

## Special Considerations
- **No Delegation**: AI agents must execute tasks directly
- **Single Task Focus**: Only one task per session
- **Verification Required**: Always run `lsp_diagnostics` and `wc -l` after changes
- **No Code Writing**: Only documentation, not implementation
- **Todo Discipline**: Use `todowrite` for multi-step tasks

## Testing Strategy
- **RED**: Confirm baseline failures (e.g., missing sections)
- **GREEN**: Write minimal documentation to pass tests
- **REFACTOR**: Close loopholes (e.g., add missing guidelines)

## Quick Reference
| Section | Purpose |
|---------|---------|
| Build | npm scripts for compiling/linting/testing |
| Style | Formatting rules for code and docs |
| Agents | Categories and usage guidelines |
| Testing | TDD workflow for documentation |

## Configuration File Locations
- **Root config**: `.sisyphus/config.json`
- **Plan files**: `.sisyphus/plans/` (read-only)
- **Notepad**: `.sisyphus/notepads/` (append only)
- **Skill docs**: `skills/` (no subagent edits)

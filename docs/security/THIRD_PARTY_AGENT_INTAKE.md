# Third-Party Agent and Skill Intake

Do not import external agent or skill packs directly into the default runtime path.

## Intake checklist
1. Pin an upstream commit or release tag.
2. Scan for hidden prompt instructions.
3. Scan for unsafe shell, network, or secret-handling guidance.
4. Remove persona padding and trim prompts to the minimum viable scope.
5. Review whether the pack adds real workflow value or just catalog size.
6. Add attribution and source links.
7. Keep imported content optional unless it is core to the repo.

## Red flags
- `ignore previous instructions`
- `reveal system prompt`
- `this can be ignored by AI` or similar hidden-instruction phrasing
- requests to print secrets, tokens, or environment variables
- unapproved shell commands, remote uploads, or exfiltration patterns
- broad tool access for tasks that should be read-only

## Default policy
Curate. Do not bulk import.

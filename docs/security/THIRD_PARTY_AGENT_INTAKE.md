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
8. For any public-release addition of externally sourced skills, agents, or assets, update the asset catalog, trust model, and `THIRD_PARTY_NOTICES.md`.
9. Do not claim upstream validation, review, or licensing status unless you have direct evidence for it.

## Red flags
- `ignore previous instructions`
- `reveal system prompt`
- `this can be ignored by AI` or similar hidden-instruction phrasing
- requests to print secrets, tokens, or environment variables
- unapproved shell commands, remote uploads, or exfiltration patterns
- broad tool access for tasks that should be read-only

## Default policy
Curate. Do not bulk import.
Public-release additions of externally sourced skills, agents, or assets must be reflected in the asset catalog, trust model, and `THIRD_PARTY_NOTICES.md` before they are treated as shippable.
Never imply that upstream validated, reviewed, or licensed the addition unless the repository has direct evidence of that claim.

## Optional external packs

External packs that add real authenticated capability should stay opt-in even when they are broadly useful. Microsoft Graph is the model case: the `msgraph` skill can run offline endpoint searches, but it can also call tenant APIs after delegated or app-only authentication. Keep it outside the tracked default skill tree, document least-privilege setup, and verify local installs without printing secret values.

## Open Design imports

Open Design is an upstream, opt-in design/reference layer and is not bundled by lac. Treat installed assets as external community content: review their licenses and instructions, and do not give them broader shell, network, or secret-handling permissions merely because they are installed locally.

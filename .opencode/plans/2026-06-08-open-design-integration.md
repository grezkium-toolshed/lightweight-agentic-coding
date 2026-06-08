# Open Design Integration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Curate Open Design's design craft files, skills, and design systems into `.opencode/` for offline/local use with local models.

**Architecture:** Fetch raw files from open-design GitHub repo via HTTPS, place into our existing `.opencode/` directory structure. Craft files go under `.opencode/craft/`, skills under `.opencode/skills/`, design systems under `.opencode/design-systems/`. No code changes — pure file curation.

**Tech Stack:** OpenDesign (Apache 2.0) — flat markdown files (`SKILL.md`, `DESIGN.md`, craft `*.md`)

**Curation totals:**
- 12 craft files → `.opencode/craft/`
- 33 skills → `.opencode/skills/<name>/SKILL.md`
- 20 design systems → `.opencode/design-systems/<name>/DESIGN.md`
- AGENTS.md update for MCP optional step
- doctor.sh check

---

### Task 1: Create `.opencode/craft/` directory and fetch all 12 craft files

**Files:**
- Create: `.opencode/craft/` directory
- Create: `.opencode/craft/README.md`
- Create: `.opencode/craft/typography.md`
- Create: `.opencode/craft/typography-hierarchy.md`
- Create: `.opencode/craft/typography-hierarchy-editorial.md`
- Create: `.opencode/craft/color.md`
- Create: `.opencode/craft/anti-ai-slop.md`
- Create: `.opencode/craft/state-coverage.md`
- Create: `.opencode/craft/animation-discipline.md`
- Create: `.opencode/craft/accessibility-baseline.md`
- Create: `.opencode/craft/rtl-and-bidi.md`
- Create: `.opencode/craft/form-validation.md`
- Create: `.opencode/craft/laws-of-ux.md`

**Step 1: Create directory**

```bash
mkdir -p .opencode/craft
```

**Step 2: Fetch each craft file from Open Design repo**

Base URL: `https://raw.githubusercontent.com/nexu-io/open-design/main/craft/`

Fetch each of the 12 files:
```bash
for f in README.md typography.md typography-hierarchy.md typography-hierarchy-editorial.md color.md anti-ai-slop.md state-coverage.md animation-discipline.md accessibility-baseline.md rtl-and-bidi.md form-validation.md laws-of-ux.md; do
  curl -f -o ".opencode/craft/$f" "https://raw.githubusercontent.com/nexu-io/open-design/main/craft/$f"
done
```

**Step 3: Verify all files exist and have content**

```bash
ls -la .opencode/craft/
wc -l .opencode/craft/*.md
```

Expected: 12 files, all non-zero.

**Step 4: Commit**

```bash
git add .opencode/craft/
git commit -m "feat: add Open Design craft/ files for local model design guardrails"
```

---

### Task 2: Create `.opencode/skills/` entries for all 33 curated skills

**Files:** Create `.opencode/skills/<name>/SKILL.md` for each of:

```
brand-guidelines     design-review        critique
creative-director    copywriting          color-expert
brainstorming        apple-hig            doc-kami-parchment
data-report          article-magazine     faq-page
deck-swiss-international   deck-open-slide-canvas   ppt-keynote
canvas-design        brandkit             algorithmic-art
research-decision-room     design-brief   competitive-ads-extractor
enhance-prompt       agent-browser        shadcn-ui
threejs              card-twitter         gsap-core
pptx-html-fidelity-audit   doc            pdf
mobile-app           saas-landing         dashboard
```

**Step 1: Create directories**

```bash
skills="brand-guidelines design-review critique creative-director copywriting color-expert brainstorming apple-hig doc-kami-parchment data-report article-magazine faq-page deck-swiss-international deck-open-slide-canvas ppt-keynote canvas-design brandkit algorithmic-art research-decision-room design-brief competitive-ads-extractor enhance-prompt agent-browser shadcn-ui threejs card-twitter gsap-core pptx-html-fidelity-audit doc pdf mobile-app saas-landing dashboard"
for skill in $skills; do
  mkdir -p ".opencode/skills/$skill"
done
```

**Step 2: Fetch each skill's SKILL.md**

```bash
for skill in $skills; do
  curl -f -o ".opencode/skills/$skill/SKILL.md" "https://raw.githubusercontent.com/nexu-io/open-design/main/skills/$skill/SKILL.md" || echo "WARNING: $skill not found"
done
```

**Step 3: Verify**

```bash
for skill in $skills; do
  echo "$skill: $(wc -c < ".opencode/skills/$skill/SKILL.md") bytes"
done
```

**Step 4: Commit**

```bash
git add .opencode/skills/
git commit -m "feat: add 33 curated Open Design skills for design, HTML, image, and research"
```

---

### Task 3: Create `.opencode/design-systems/` with 20 starter brands

**Step 1: Create directories**

```bash
systems="default warm-editorial linear-app vercel opencode-ai apple stripe github claude cursor notion supabase minimal brutalism enterprise editorial dark shadcn spotify airbnb"
for ds in $systems; do
  mkdir -p ".opencode/design-systems/$ds"
done
```

**Step 2: Fetch each DESIGN.md**

```bash
for ds in $systems; do
  curl -f -o ".opencode/design-systems/$ds/DESIGN.md" "https://raw.githubusercontent.com/nexu-io/open-design/main/design-systems/$ds/DESIGN.md" || echo "WARNING: $ds not found"
done
```

**Step 3: Verify**

```bash
for ds in $systems; do
  echo "$ds: $(wc -c < ".opencode/design-systems/$ds/DESIGN.md") bytes"
done
```

**Step 4: Commit**

```bash
git add .opencode/design-systems/
git commit -m "feat: add 20 curated Open Design design systems for brand-constrained output"
```

---

### Task 4: Document MCP integration in AGENTS.md

**Files:**
- Modify: `AGENTS.md`

**Step 1: Read current AGENTS.md to find the right insertion point**

Add under a new `## Open Design` section:

```markdown
## Open Design

Open Design (nexu-io/open-design) provides design skills, craft rules, and brand design systems
curated under `.opencode/craft/`, `.opencode/skills/`, and `.opencode/design-systems/`.
These work offline without any daemon.

For the full 155-skill / 150-design-system catalog, optionally install the MCP server:

```bash
curl -fsSL https://open-design.ai/install.sh | sh -s opencode
# Or if od CLI is already installed:
od mcp install opencode
```
```

**Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: add Open Design MCP integration instructions"
```

---

### Task 5: Verify with doctor script

**Step 1: Run the doctor check**

```bash
./scripts/doctor.sh
```

Expected: no errors. If errors appear, fix before proceeding.

**Step 2: Verify directory structure**

```bash
echo "Craft files: $(ls .opencode/craft/ | wc -l) (expected 12)"
echo "Skills added: $(ls -d .opencode/skills/*/ | wc -l) (expect ~41 total including existing)"
echo "Design systems: $(ls -d .opencode/design-systems/*/ | wc -l) (expected 20)"
```

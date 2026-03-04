$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$OutJson = Join-Path $Root 'docs/free-coding-models.json'
$OutMd = Join-Path $Root 'docs/FREE_CLOUD_MODELS.md'
$Url = 'https://raw.githubusercontent.com/vava-nessa/free-coding-models/main/sources.js'
$Tmp = Join-Path $env:TEMP "free-coding-models-$([guid]::NewGuid()).js"

Invoke-WebRequest -Uri $Url -OutFile $Tmp

$py = @"
import json,re
from pathlib import Path
raw=Path(r'$Tmp').read_text(encoding='utf-8')
providers=['nvidiaNim','groq','cerebras','sambanova','openrouter','googleai','zai','siliconflow','together','cloudflare','perplexity']
out={}
for p in providers:
    m=re.search(rf"export const {re.escape(p)} = \\[(.*?)\\n\\]", raw, re.S)
    if not m:
        continue
    body=m.group(1)
    rows=[]
    for mm in re.finditer(r"\\['([^']+)'\\s*,\\s*'([^']+)'\\s*,\\s*'([^']+)'\\s*,\\s*'([^']+)'\\s*,\\s*'([^']+)'\\]", body):
        rows.append({'id':mm.group(1),'label':mm.group(2),'tier':mm.group(3),'swe':mm.group(4),'context':mm.group(5)})
    out[p]=rows
Path(r'$OutJson').write_text(json.dumps(out,indent=2)+'\\n',encoding='utf-8')
lines=['# Free Cloud Coding Models Snapshot','','Source: [vava-nessa/free-coding-models](https://github.com/vava-nessa/free-coding-models)','', 'Kudos to **@vava-nessa** for the free model index and NIM helper tooling.','']
for provider,models in out.items():
    lines.append(f'## {provider}')
    lines.append('')
    if not models:
        lines.append('No models parsed from upstream source.')
        lines.append('')
        continue
    lines.append('| Model ID | Label | Tier | SWE | Context |')
    lines.append('|---|---|---|---|---|')
    for m in models[:40]:
        lines.append(f"| `{m['id']}` | {m['label']} | {m['tier']} | {m['swe']} | {m['context']} |")
    if len(models)>40:
        lines.append(f"| ... | ... and {len(models)-40} more |  |  |  |")
    lines.append('')
Path(r'$OutMd').write_text('\\n'.join(lines)+'\\n',encoding='utf-8')
"@

python3 -c $py
Remove-Item $Tmp -Force
Write-Host "Wrote: $OutJson"
Write-Host "Wrote: $OutMd"

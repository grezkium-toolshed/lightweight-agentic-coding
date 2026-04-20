$ErrorActionPreference = 'Stop'
$Root = if ($env:AI_CLUSTER_ROOT) { $env:AI_CLUSTER_ROOT } else { Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$OutJson = Join-Path $Root 'docs/free-coding-models.json'
$OutMd = Join-Path $Root 'docs/FREE_CLOUD_MODELS.md'
$Url = 'https://raw.githubusercontent.com/vava-nessa/free-coding-models/main/sources.js'
$Tmp = Join-Path $env:TEMP "free-coding-models-$([guid]::NewGuid()).js"

Invoke-WebRequest -Uri $Url -OutFile $Tmp

$SnapshotDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')

$py = @"
import json,re
from pathlib import Path
raw=Path(r'$Tmp').read_text(encoding='utf-8')
source_url=r'$Url'
snapshot_date=r'$SnapshotDate'
providers=['nvidiaNim','groq','cerebras','sambanova','openrouter','googleai','zai','siliconflow','together','cloudflare','perplexity']
out={'_meta':{'snapshot_date':snapshot_date,'source_url':source_url,'verification_method':'upstream-sync','live_probe_command':'./bin/lac provider verify --all'}}
lines=raw.splitlines()
for p in providers:
    start=next((i for i,line in enumerate(lines) if re.match(rf"\\s*export const {re.escape(p)}\\s*=\\s*\\[", line)), None)
    if start is None:
        continue
    body_lines=[]
    for line in lines[start+1:]:
        if line.strip()==']':
            break
        body_lines.append(line)
    body='\\n'.join(body_lines)
    rows=[]
    for mm in re.finditer(r"\['([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'\]", body):
        rows.append({'id':mm.group(1),'label':mm.group(2),'tier':mm.group(3),'swe':mm.group(4),'context':mm.group(5)})
    out[p]=rows
Path(r'$OutJson').write_text(json.dumps(out,indent=2)+'\\n',encoding='utf-8')
lines=['# Free Cloud Coding Models Snapshot','','Source: [vava-nessa/free-coding-models](https://github.com/vava-nessa/free-coding-models)','', f'**Last verified:** {snapshot_date} (upstream sync; regenerate with `./scripts/sync-free-cloud-models.sh` or `.ps1`).','', 'Kudos to **@vava-nessa** for the free model index and NIM helper tooling.','']
for provider,models in out.items():
    if provider=='_meta':
        continue
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

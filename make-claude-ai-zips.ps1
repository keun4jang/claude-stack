<#
.SYNOPSIS
  Build spec-compliant ZIPs of the marketing skills for upload to claude.ai.

.DESCRIPTION
  claude.ai custom Skills are the ONLY account-level path that reaches cloud
  sessions with no PC running and no per-repo commit. Per the Claude Code
  carry-over table: "Skills you enable on claude.ai are loaded into cloud
  sessions automatically."

  There is no bulk upload and no API for them -- the Skills API (/v1/skills)
  is a different store: "Skills uploaded through the API are not available on
  claude.ai." So the upload itself is manual, via Settings > Features.

  Why this script exists instead of Compress-Archive: PowerShell 5.1's
  Compress-Archive writes ZIP entries with backslash separators, which
  violates the ZIP spec (APPNOTE 4.4.17 requires forward slashes). The
  uploader looks for "<skill>/SKILL.md" and would reject "<skill>\SKILL.md"
  as a missing SKILL.md. This writes entries by hand with forward slashes.

  Skipped deliberately: remotion-* and mediabunny. They need a local repo,
  npm, and rendering, none of which exist in the claude.ai sandbox.

.EXAMPLE
  .\make-claude-ai-zips.ps1
  .\make-claude-ai-zips.ps1 -Bundled     # one skill instead of 47
#>
param(
    [string]$SkillsDir = "$HOME\.agents\skills",
    [string]$OutDir    = "$PSScriptRoot\..\claude-ai-upload",
    [switch]$Bundled
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$SEP = [char]92   # backslash, via char code so no literal appears in the source

function New-SpecZip {
    param([string]$SourceDir, [string]$ZipPath, [string]$RootName)

    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    $fs  = [System.IO.File]::Open($ZipPath, 'Create')
    $zip = New-Object System.IO.Compression.ZipArchive($fs, 'Create')
    try {
        foreach ($f in (Get-ChildItem -LiteralPath $SourceDir -Recurse -File)) {
            $rel  = $f.FullName.Substring($SourceDir.Length).TrimStart($SEP)
            $name = "$RootName/" + ($rel.Replace($SEP, '/'))
            $e  = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
            $es = $e.Open()
            $b  = [System.IO.File]::ReadAllBytes($f.FullName)
            $es.Write($b, 0, $b.Length)
            $es.Dispose()
        }
    } finally { $zip.Dispose(); $fs.Dispose() }
}

function Test-SpecZip {
    param([string]$ZipPath)
    $a = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $backslashes = @($a.Entries | Where-Object { $_.FullName.Contains($SEP) }).Count
        $hasSkillMd  = @($a.Entries | Where-Object { $_.FullName -match '(^|/)SKILL\.md$' }).Count
        [PSCustomObject]@{ Backslashes = $backslashes; SkillMdCount = $hasSkillMd }
    } finally { $a.Dispose() }
}

$skills = Get-ChildItem -LiteralPath $SkillsDir -Directory |
          Where-Object { $_.Name -notlike 'remotion-*' -and $_.Name -ne 'mediabunny' }

if (-not $skills) { throw "No skills found under $SkillsDir" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ($Bundled) {
    # One skill, 47 references. Trades per-skill auto-triggering for a single
    # upload and a much smaller always-on cost: one description in the system
    # prompt (~200 tok) instead of 47 (~8,400 tok).
    $staging = Join-Path $OutDir '_staging/marketing'
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -ItemType Directory -Force -Path "$staging/skills" | Out-Null

    $index = @()
    foreach ($s in $skills) {
        Copy-Item -LiteralPath $s.FullName -Destination "$staging/skills/$($s.Name)" -Recurse
        # -Encoding UTF8 matters: these files have no BOM, and PS 5.1 otherwise
        # reads them as ANSI, turning every em-dash in a description into "??".
        $fm = Get-Content -LiteralPath (Join-Path $s.FullName 'SKILL.md') -Raw -Encoding UTF8
        $d  = if ($fm -match '(?ms)^description:\s*(.+?)(?=^\w+:|^---)') { ($matches[1] -replace '\s+', ' ').Trim() } else { '' }
        $d  = $d.Trim([char]34, [char]39)          # some descriptions are quoted in source
        $d  = $d -replace '\|', '/'                # a pipe would break the markdown table
        if ($d.Length -gt 160) { $d = $d.Substring(0, 157) + '...' }
        $index += "| ``$($s.Name)`` | $d |"
    }

    $body = @"
---
name: marketing
description: Marketing expertise across 47 areas - copywriting, conversion optimization, SEO and AI search, paid ads and ad creative, email and cold outreach, pricing and offers, positioning, launches, onboarding, retention and churn, referrals, analytics, competitor research, PR, social, and sales enablement. Use whenever the user asks about marketing, growth, copy, landing pages, ads, SEO, email, pricing, or acquiring and keeping customers.
---

# Marketing

47 marketing skills. Each lives in ``skills/<name>/SKILL.md``.

## How to use this

1. Find the row below matching the request.
2. Read ``skills/<name>/SKILL.md`` and follow it.
3. That file may point to more files under its own ``references/`` - read those as needed.

Read only what the task needs. Do not read all 47.

## Index

| Skill | Use when |
|---|---|
$($index -join "`n")
"@
    Set-Content -LiteralPath "$staging/SKILL.md" -Value $body -Encoding utf8 -NoNewline

    $zipPath = Join-Path $OutDir 'marketing.zip'
    New-SpecZip -SourceDir (Resolve-Path $staging).Path -ZipPath $zipPath -RootName 'marketing'
    Remove-Item -LiteralPath (Join-Path $OutDir '_staging') -Recurse -Force

    $r = Test-SpecZip $zipPath
    Write-Host "==> marketing.zip  ($([math]::Round((Get-Item $zipPath).Length/1KB,1)) KB, $($skills.Count) skills bundled)" -ForegroundColor Cyan
    Write-Host "    backslash entries: $($r.Backslashes)  (must be 0)   SKILL.md files: $($r.SkillMdCount)" -ForegroundColor DarkGray
    Write-Host "`nUpload this ONE file at claude.ai > Settings > Features > Skills." -ForegroundColor Green

} else {
    $indiv = Join-Path $OutDir 'individual'
    New-Item -ItemType Directory -Force -Path $indiv | Out-Null
    $bad = 0
    foreach ($s in $skills) {
        $zp = Join-Path $indiv "$($s.Name).zip"
        New-SpecZip -SourceDir $s.FullName -ZipPath $zp -RootName $s.Name
        $r = Test-SpecZip $zp
        if ($r.Backslashes -gt 0 -or $r.SkillMdCount -lt 1) { Write-Host "  BAD: $($s.Name)" -ForegroundColor Red; $bad++ }
    }
    $z = Get-ChildItem $indiv -Filter *.zip
    Write-Host "==> $($z.Count) ZIPs, $([math]::Round(($z | Measure-Object Length -Sum).Sum/1KB,1)) KB total" -ForegroundColor Cyan
    Write-Host "    spec violations: $bad  (must be 0)" -ForegroundColor DarkGray
    Write-Host "`nUpload each at claude.ai > Settings > Features > Skills." -ForegroundColor Green
}

Write-Host "Output: $((Resolve-Path $OutDir).Path)" -ForegroundColor DarkGray

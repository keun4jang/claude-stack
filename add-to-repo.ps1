<#
.SYNOPSIS
  Make the stack load automatically in cloud sessions for one repo.

.DESCRIPTION
  Cloud sessions (claude.ai/code, and the Code tab in the Claude mobile app)
  run on a fresh Anthropic VM with only your repo cloned. They never read
  ~/.claude. The official carry-over table is blunt about it:

    Plugins declared in .claude/settings.json  -> Yes, "Installed at session
                                                  start from the marketplace
                                                  you declared"
    Plugins enabled only in your user settings -> No
    Your user ~/.claude/skills/                -> No

  So the config has to live in the repo. This script writes it, per repo,
  and merges instead of clobbering if the repo already has settings.

  Run it once per repo you want to use from the phone without your PC on.
  Then commit the file.

.EXAMPLE
  .\add-to-repo.ps1 C:\Projects\my-app
  .\add-to-repo.ps1 .              # current repo
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$RepoPath,

    # Bundle = all 5 (11k tokens/session). Use -Only to pick a subset.
    [string[]]$Only
)

$ErrorActionPreference = 'Stop'

$RepoPath = (Resolve-Path $RepoPath).Path
if (-not (Test-Path (Join-Path $RepoPath '.git'))) {
    Write-Host "!! $RepoPath is not a git repo. Cloud sessions clone from git," -ForegroundColor Yellow
    Write-Host "   so config only reaches them if it is committed." -ForegroundColor Yellow
}

$claudeDir = Join-Path $RepoPath '.claude'
$settingsPath = Join-Path $claudeDir 'settings.json'

$plugins = if ($Only) {
    $h = @{}; foreach ($p in $Only) { $h["$p@rmsdu-stack"] = $true }; $h
} else {
    @{ 'my-stack@rmsdu-stack' = $true }
}

$marketplace = @{
    'rmsdu-stack' = @{
        source     = @{ source = 'github'; repo = 'keun4jang/claude-stack' }
        autoUpdate = $true
    }
}

if (Test-Path $settingsPath) {
    Write-Host "==> Merging into existing $settingsPath" -ForegroundColor Cyan
    $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json

    # ConvertFrom-Json gives PSCustomObject; convert the two keys we touch to
    # hashtables so we can add to them, and leave every other key untouched.
    $obj = @{}
    foreach ($p in $existing.PSObject.Properties) { $obj[$p.Name] = $p.Value }

    $mk = @{}
    if ($obj.extraKnownMarketplaces) {
        foreach ($p in $obj.extraKnownMarketplaces.PSObject.Properties) { $mk[$p.Name] = $p.Value }
    }
    foreach ($k in $marketplace.Keys) { $mk[$k] = $marketplace[$k] }
    $obj.extraKnownMarketplaces = $mk

    $ep = @{}
    if ($obj.enabledPlugins) {
        foreach ($p in $obj.enabledPlugins.PSObject.Properties) { $ep[$p.Name] = $p.Value }
    }
    foreach ($k in $plugins.Keys) { $ep[$k] = $plugins[$k] }
    $obj.enabledPlugins = $ep

    $out = $obj
} else {
    Write-Host "==> Creating $settingsPath" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    $out = @{
        extraKnownMarketplaces = $marketplace
        enabledPlugins         = $plugins
    }
}

$out | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
Write-Host "    OK  written" -ForegroundColor Green
Get-Content $settingsPath | Write-Host -ForegroundColor DarkGray

Write-Host "`n==> Commit it - uncommitted files do not reach a cloud session:" -ForegroundColor Cyan
Write-Host "    cd `"$RepoPath`"" -ForegroundColor White
Write-Host "    git add .claude/settings.json && git commit -m 'Load Claude stack in cloud sessions'" -ForegroundColor White
Write-Host "    git push" -ForegroundColor White
Write-Host "`nAfter that, any cloud session on this repo installs the stack at startup," -ForegroundColor DarkGray
Write-Host "with no PC running. Locally, you get a one-time install prompt on folder trust." -ForegroundColor DarkGray

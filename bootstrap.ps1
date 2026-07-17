<#
.SYNOPSIS
  Reproduce rmsdu's Claude Code stack on a fresh machine.

.DESCRIPTION
  Two routes. Pick ONE for skills - never both, or every skill loads twice
  and you pay ~8k extra tokens per session for duplicates.

    -Route marketplace   (default) Everything via the rmsdu-stack marketplace.
                         2 commands. Skills are namespaced (marketing-skills:cro).
                         Version-pinnable. This is the portable route.

    -Route classic       The original setup: 3 plugins via marketplaces,
                         55 skills via the `skills` npm CLI at user scope.
                         Skills are un-namespaced (cro). Always tracks HEAD.

.EXAMPLE
  .\bootstrap.ps1
  .\bootstrap.ps1 -Route classic
#>
param(
    [ValidateSet('marketplace', 'classic')]
    [string]$Route = 'marketplace',

    [string]$MarketplaceRepo = 'rmsdu/claude-stack'
)

$ErrorActionPreference = 'Stop'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }

Step "Checking prerequisites"
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "claude CLI not found on PATH. Install Claude Code first: https://claude.com/claude-code"
}
Ok "claude $((claude --version) -replace '\s*\(.*\)','')"

if ($Route -eq 'marketplace') {

    Step "Adding marketplace: $MarketplaceRepo"
    claude plugin marketplace add $MarketplaceRepo
    Ok "marketplace rmsdu-stack registered"

    Step "Installing the whole stack (1 command, 5 dependencies)"
    claude plugin install my-stack@rmsdu-stack --scope user
    Ok "my-stack + claude-mem, superpowers, ui-ux-pro-max, marketing-skills, remotion-skills"

    Warn "Skills are namespaced under this route, e.g. marketing-skills:cro not cro."
    Warn "Do NOT also run the classic route - you would load every skill twice."

} else {

    Step "Installing the 3 plugins"
    claude plugin marketplace add thedotmack/claude-mem
    claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
    # claude-plugins-official is built in - no marketplace add needed.
    claude plugin install claude-mem@thedotmack --scope user
    claude plugin install superpowers@claude-plugins-official --scope user
    claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill --scope user
    Ok "3 plugins installed"

    Step "Installing 55 skills via the skills CLI"
    # cwd matters: the skills CLI writes skills-lock.json to the current dir and
    # treats it as a project lock. Running from $HOME is what makes `update -p`
    # work later. Do NOT use -g: it looks for a different lock and finds nothing.
    Push-Location $HOME
    try {
        npx --yes skills@latest add remotion-dev/skills -a claude-code -y
        npx --yes skills@latest add coreyhaines31/marketingskills -a claude-code -y
    } finally { Pop-Location }
    Ok "skills installed to ~/.agents/skills, junctioned into ~/.claude/skills"

    Warn "To update later: cd `$HOME; npx --yes skills@latest update -p -y"
    Warn "(-g silently does nothing - the lock lives at ~/skills-lock.json)"
}

Step "Applying non-plugin settings"
$src = Join-Path $PSScriptRoot 'dotfiles\settings.json'
$dst = Join-Path $HOME '.claude\settings.json'
if (Test-Path $dst) {
    Warn "settings.json already exists - not overwriting."
    Warn "Merge by hand if you want the keys from $src"
} elseif (Test-Path $src) {
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item $src $dst
    Ok "settings.json written (plugin keys are managed by the CLI, not this file)"
}

Step "Verifying"
claude plugin list

Write-Host "`nDone. Restart Claude Code to load everything." -ForegroundColor Green
Write-Host "Sign in separately with: claude auth login" -ForegroundColor DarkGray
Write-Host "(credentials are never stored in this repo)" -ForegroundColor DarkGray

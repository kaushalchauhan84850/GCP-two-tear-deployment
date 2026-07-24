# Loads a .env-style file (KEY=VALUE per line) into the current PowerShell
# session as environment variables. Must be "dot-sourced" so the variables
# persist in your shell (a normal run would only set them in a subprocess):
#
#   . .\scripts\load-env.ps1 .\backend\.env
#   . .\scripts\load-env.ps1 .\terraform\.env.dev
#
# Lines starting with # are ignored. Blank lines are ignored.

param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

if (-not (Test-Path $Path)) {
  Write-Error "Env file not found: $Path"
  return
}

Get-Content $Path | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq "" -or $line.StartsWith("#")) { return }

  $idx = $line.IndexOf("=")
  if ($idx -lt 1) { return }

  $key = $line.Substring(0, $idx).Trim()
  $value = $line.Substring($idx + 1).Trim()

  Set-Item -Path "Env:$key" -Value $value
  Write-Host "Set $key" -ForegroundColor DarkGray
}

Write-Host "Loaded environment variables from $Path" -ForegroundColor Green

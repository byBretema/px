# Makes the current dir a px project, named after it, with new.cmake from the
# same px release:
#   mkdir hello; cd hello; irm https://github.com/byBretema/px/releases/latest/download/new.ps1 | iex
# Arguments go to cmake:
#   & ([scriptblock]::Create((irm https://github.com/byBretema/px/releases/latest/download/new.ps1))) -D NAME=<name>
# new.sh is the Unix twin: keep both in step.
# The release job pins the URL below to its own release.
# In a script block: `return` ends it without closing the session that runs iex.
& {
  $ErrorActionPreference = 'Stop'

  $url = 'https://github.com/byBretema/px/releases/latest/download/new.cmake'

  foreach ($tool in 'cmake', 'git') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
      Write-Host "px: $tool not found; px needs CMake 3.28+ and git" -ForegroundColor Red
      return
    }
  }

  # new.cmake refuses a non-empty dir without FORCE; ask here, as CMake can't.
  $cmakeArgs = @($args)
  if (-not ($cmakeArgs -match 'FORCE=ON') -and (Get-ChildItem -Force | Where-Object Name -ne '.git')) {
    try {
      $answer = Read-Host "px: $PWD isn't empty; files named like the template's will be replaced. Continue? [y/N]"
    } catch {
      Write-Host "px: no terminal to ask on; pass -D FORCE=ON (the [scriptblock] form above)" -ForegroundColor Red
      return
    }
    if ($answer -notmatch '^[yY]') {
      Write-Host 'px: aborted'
      return
    }
    $cmakeArgs += '-D', 'FORCE=ON'
  }

  $script = Join-Path ([IO.Path]::GetTempPath()) "px-new-$PID.cmake"
  try {
    Invoke-RestMethod -Uri $url -OutFile $script
    cmake @cmakeArgs -P $script
  } finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $script
  }
} @args

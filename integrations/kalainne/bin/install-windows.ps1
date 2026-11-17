# Instala o Archify da Kalainne no Windows.
# Baixa o fork, instala as dependencias, grava o skill no usuario e,
# se houver projetos, registra cada pasta existente.
#
# No PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\integrations\kalainne\bin\install-windows.ps1
#
# Sem o repositorio ainda, salve este arquivo e rode o mesmo comando.
# Projetos opcionais, so pastas que ja existem:
#   .\install-windows.ps1 -Project C:\src\site-kalainne -Project C:\src\kalainne-salon-pro

[CmdletBinding()]
param(
  [string]$Checkout,
  [string]$RepoUrl = 'https://github.com/kaairofelipedev/archify.git',
  [string]$Branch = 'main',
  [string[]]$Project = @(),
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'

if (-not $Checkout) {
  $Checkout = Join-Path $env:USERPROFILE 'src\archify'
}

function Test-CommandAvailable {
  param([Parameter(Mandatory = $true)][string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Update-SessionPath {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$user"
}

function Install-WithWinget {
  param([Parameter(Mandatory = $true)][string]$Id)
  if (-not (Test-CommandAvailable 'winget')) {
    throw "winget nao esta disponivel. Instale $Id manualmente e rode este script de novo."
  }
  Write-Host "Instalando $Id"
  & winget install --id $Id -e --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) {
    throw "winget nao concluiu a instalacao de $Id (codigo $LASTEXITCODE)."
  }
  Update-SessionPath
}

function Get-NodeVersion {
  $raw = (& node -p 'process.versions.node').Trim()
  $parts = $raw.Split('.')
  return @{
    Raw = $raw
    Major = [int]$parts[0]
    Minor = [int]$parts[1]
  }
}

function Test-NodeIsNewEnough {
  param($Version)
  if ($Version.Major -gt 22) { return $true }
  if ($Version.Major -lt 22) { return $false }
  return $Version.Minor -ge 20
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][string[]]$ArgumentList,
    [Parameter(Mandatory = $true)][string]$Failure
  )
  & $File @ArgumentList
  if ($LASTEXITCODE -ne 0) {
    throw "$Failure (codigo $LASTEXITCODE)."
  }
}

if (-not (Test-CommandAvailable 'git')) {
  Install-WithWinget 'Git.Git'
}
if (-not (Test-CommandAvailable 'git')) {
  throw 'Git foi instalado, mas esta sessao ainda nao o encontra. Feche o terminal, abra outro e rode o script de novo.'
}

$nodeReady = $false
if (Test-CommandAvailable 'node') {
  $nodeReady = Test-NodeIsNewEnough (Get-NodeVersion)
}
if (-not $nodeReady) {
  Install-WithWinget 'OpenJS.NodeJS.LTS'
}
if (-not (Test-CommandAvailable 'node')) {
  throw 'Node.js foi instalado, mas esta sessao ainda nao o encontra. Feche o terminal, abra outro e rode o script de novo.'
}
$nodeVersion = Get-NodeVersion
if (-not (Test-NodeIsNewEnough $nodeVersion)) {
  throw "Node.js $($nodeVersion.Raw) e antigo demais. O instalador de skills precisa de Node 22.20 ou mais novo."
}

$checkoutParent = Split-Path -Parent $Checkout
if (-not (Test-Path -LiteralPath $checkoutParent)) {
  New-Item -ItemType Directory -Force -Path $checkoutParent | Out-Null
}

if (Test-Path -LiteralPath (Join-Path $Checkout '.git')) {
  Write-Host "Atualizando $Checkout"
  Invoke-Checked 'git' @('-C', $Checkout, 'fetch', 'origin', $Branch) 'git fetch falhou'
  Invoke-Checked 'git' @('-C', $Checkout, 'checkout', $Branch) 'git checkout falhou'
  Invoke-Checked 'git' @('-C', $Checkout, 'pull', '--ff-only', 'origin', $Branch) 'git pull falhou'
} elseif (Test-Path -LiteralPath $Checkout) {
  throw "A pasta existe e nao e um repositorio Git: $Checkout"
} else {
  Write-Host "Baixando $RepoUrl em $Checkout"
  Invoke-Checked 'git' @('clone', '--branch', $Branch, '--single-branch', $RepoUrl, $Checkout) 'git clone falhou'
}

$installer = Join-Path $Checkout 'integrations\kalainne\bin\install.mjs'
if (-not (Test-Path -LiteralPath $installer)) {
  throw "Este checkout nao tem o instalador da Kalainne: $installer"
}

Push-Location $Checkout
try {
  Write-Host 'Instalando dependencias do repositorio'
  Invoke-Checked 'npm' @('ci', '--no-audit', '--no-fund') 'npm ci na raiz falhou'
  Invoke-Checked 'npm' @('--prefix', 'archify', 'ci', '--no-audit', '--no-fund') 'npm ci em archify falhou'

  Write-Host 'Gravando o skill kalainne-archify no usuario'
  Invoke-Checked 'node' @(
    'integrations/kalainne/bin/install.mjs',
    'install', '--scope', 'user',
    '--home', $env:USERPROFILE,
    '--json'
  ) 'install --scope user falhou'

  $existingProjects = @()
  foreach ($item in $Project) {
    if (Test-Path -LiteralPath $item -PathType Container) {
      $existingProjects += (Resolve-Path -LiteralPath $item).Path
    } else {
      Write-Warning "Projeto ignorado, pasta nao existe: $item"
    }
  }

  $targetsFile = Join-Path $Checkout 'integrations\kalainne\targets.json'
  if ($existingProjects.Count -gt 0) {
    $counts = @{}
    $projectLines = @()
    foreach ($projectPath in $existingProjects) {
      $base = Split-Path -Leaf $projectPath
      $count = 0
      if ($counts.ContainsKey($base)) { $count = [int]$counts[$base] }
      $counts[$base] = $count + 1
      $id = $base
      if ($count -gt 0) { $id = "$base-$count" }
      $idJson = (ConvertTo-Json $id).Trim()
      $pathJson = (ConvertTo-Json $projectPath).Trim()
      $projectLines += "    { `"id`": $idJson, `"path`": $pathJson }"
    }
    $checkoutJson = (ConvertTo-Json $Checkout).Trim()
    $json = @"
{
  "schema_version": 1,
  "archifyCheckout": $checkoutJson,
  "projects": [
$($projectLines -join ",`n")
  ]
}

"@
    [System.IO.File]::WriteAllText($targetsFile, $json, (New-Object System.Text.UTF8Encoding $false))
  }

  if (Test-Path -LiteralPath $targetsFile) {
    Write-Host 'Registrando os projetos listados em targets.json'
    Invoke-Checked 'node' @(
      'integrations/kalainne/bin/bootstrap.mjs',
      '--targets', 'integrations/kalainne/targets.json',
      '--with-user',
      '--home', $env:USERPROFILE,
      '--json'
    ) 'bootstrap falhou'
  } else {
    Write-Host 'Nenhum targets.json. O skill de usuario foi instalado. Para outros projetos, rode de novo com -Project.'
  }

  Write-Host 'Instalando o skill publico archify no Cursor'
  Invoke-Checked 'npx' @(
    '-y', 'skills', 'add', 'tt-a1i/archify',
    '--skill', 'archify',
    '--agent', 'cursor',
    '--global', '--copy', '--yes'
  ) 'a instalacao do skill archify falhou'

  Write-Host 'Conferindo o CLI'
  Invoke-Checked 'node' @(
    'integrations/kalainne/bin/install.mjs',
    'doctor',
    '--target', $Checkout,
    '--home', $env:USERPROFILE,
    '--json'
  ) 'doctor falhou'
} finally {
  Pop-Location
}

$skillFiles = @(
  (Join-Path $env:USERPROFILE '.agents\skills\kalainne-archify\SKILL.md'),
  (Join-Path $env:USERPROFILE '.cursor\skills\kalainne-archify\SKILL.md')
)
foreach ($skillFile in $skillFiles) {
  if (-not (Test-Path -LiteralPath $skillFile)) {
    throw "O skill nao foi gravado: $skillFile"
  }
}

Write-Host ''
Write-Host 'Pronto.'
Write-Host "Checkout: $Checkout"
Write-Host "Skill: $(Join-Path $env:USERPROFILE '.cursor\skills\kalainne-archify')"
Write-Host 'Feche e abra o Cursor para ele ler o skill.'
Write-Host 'Mapas:'
Get-ChildItem -LiteralPath (Join-Path $Checkout 'integrations\kalainne\artifacts') -Filter '*.html' | ForEach-Object {
  Write-Host "  $($_.FullName)"
  if (-not $NoBrowser) {
    Start-Process $_.FullName
  }
}

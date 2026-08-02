<#
.SYNOPSIS
    Instala os agentes e skills da Eng Company no Claude Code.

.DESCRIPTION
    Copia .claude/agents/*.md e skills/* para o destino.
    Global (~/.claude) por padrao; use -Project para instalar num repo especifico.

.EXAMPLE
    .\scripts\install.ps1
    .\scripts\install.ps1 -Project C:\repos\meu-produto
    .\scripts\install.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Project
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

if ($Project) {
    if (-not (Test-Path $Project)) { throw "Projeto nao encontrado: $Project" }
    $dest = Join-Path $Project '.claude'
    $scope = "projeto ($Project)"
} else {
    $dest = Join-Path $HOME '.claude'
    $scope = 'global (~/.claude)'
}

Write-Host "Eng Company -> $scope" -ForegroundColor Cyan

$agentsSrc = Join-Path $repo '.claude\agents'
$skillsSrc = Join-Path $repo 'skills'
foreach ($p in @($agentsSrc, $skillsSrc)) {
    if (-not (Test-Path $p)) { throw "Nao encontrado: $p (rode a partir do repo clonado)" }
}

$agentsDst = Join-Path $dest 'agents'
$skillsDst = Join-Path $dest 'skills'

if ($PSCmdlet.ShouldProcess($dest, 'Instalar agentes e skills')) {
    New-Item -ItemType Directory -Force -Path $agentsDst, $skillsDst | Out-Null

    Copy-Item (Join-Path $agentsSrc '*.md') $agentsDst -Force
    Copy-Item (Join-Path $skillsSrc 'eng-*') $skillsDst -Recurse -Force

    Write-Host "`nAgentes:" -ForegroundColor Green
    Get-ChildItem $agentsDst -Filter 'eng-*.md' | ForEach-Object { "  $($_.BaseName)" }

    Write-Host "`nSkills:" -ForegroundColor Green
    Get-ChildItem $skillsDst -Directory -Filter 'eng-*' | ForEach-Object { "  $($_.Name)" }

    Write-Host "`nPronto. Abra o Claude Code no repo do seu produto e chame:" -ForegroundColor Cyan
    Write-Host '  usa o eng-ceo: <seu pedido>'
    Write-Host "`nAntes de usar em producao, preencha agents/ceo/references/mandato.md" -ForegroundColor Yellow
}

param(
    [string]$AddOnsPath = 'C:\Jogos\World of Warcraft\_retail_\Interface\AddOns'
)
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$targetRoot = [IO.Path]::GetFullPath((Join-Path $AddOnsPath 'BlockBags'))
if ($sourceRoot -eq $targetRoot) { throw 'Execute este comando na pasta de desenvolvimento, fora do jogo.' }
$entries = @('BlockBags.toc', 'Bindings.xml', 'LICENSE', 'THIRD_PARTY_NOTICES.md')
foreach ($line in Get-Content -LiteralPath (Join-Path $sourceRoot 'BlockBags.toc')) {
    $entry = $line.Trim()
    if ($entry -and -not $entry.StartsWith('#')) { $entries += $entry }
}
# Validate every entry before copying anything. Do not delete unrelated files.
foreach ($entry in $entries) {
    $sourceFile = [IO.Path]::GetFullPath((Join-Path $sourceRoot $entry))
    $targetFile = [IO.Path]::GetFullPath((Join-Path $targetRoot $entry))
    if (-not $sourceFile.StartsWith($sourceRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        -not $targetFile.StartsWith($targetRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        throw "Arquivo invalido no pacote: $entry"
    }
}
foreach ($entry in $entries) {
    $sourceFile = Join-Path $sourceRoot $entry
    $targetFile = Join-Path $targetRoot $entry
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetFile) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    if ((Get-FileHash -LiteralPath $sourceFile).Hash -ne (Get-FileHash -LiteralPath $targetFile).Hash) {
        throw "Falha ao verificar a copia: $entry"
    }
}
Write-Output "BlockBags atualizado em $targetRoot ($($entries.Count) arquivos). Use /reload no WoW."

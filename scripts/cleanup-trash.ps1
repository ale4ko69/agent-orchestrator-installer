param(
    [int]$RetentionDays = 7,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($RetentionDays -lt 0) {
    throw "RetentionDays must be 0 or greater."
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$trashRoot = Join-Path $repoRoot ".trash"
if (-not (Test-Path -LiteralPath $trashRoot)) {
    return
}

$trashRootResolved = (Resolve-Path -LiteralPath $trashRoot).Path
$cutoff = (Get-Date).AddDays(-$RetentionDays)

Get-ChildItem -LiteralPath $trashRootResolved -Force | Where-Object {
    $_.LastWriteTime -lt $cutoff
} | ForEach-Object {
    $entryPath = (Resolve-Path -LiteralPath $_.FullName).Path
    $trashPrefix = $trashRootResolved.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $entryPath.StartsWith($trashPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove outside .trash: $entryPath"
    }

    if ($DryRun) {
        Write-Host "[DRY-RUN] remove trash entry: $entryPath"
        return
    }

    Remove-Item -LiteralPath $entryPath -Recurse -Force
}

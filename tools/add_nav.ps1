param(
  [Parameter(Mandatory=$true)][string]$Path,
  [Parameter(Mandatory=$true)][string]$Selector,
  [Parameter(Mandatory=$true)][string]$Dest
)
$c = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$segment = $Selector.Trim()
if($c -match ('(\<div[^>]*class="' + [regex]::Escape($segment) + '")')){
  $c = $c -replace ('(\<div[^>]*class="' + [regex]::Escape($segment) + ')")([^>]*)>'), ('$1' + " data-nav=`"$Dest`"" + '$3>')
  [System.IO.File]::WriteAllText((Resolve-Path $Path), $c, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "OK $Path $Selector -> $Dest"
} else {
  Write-Host "INTROUVABLE: $Path $Selector"
}
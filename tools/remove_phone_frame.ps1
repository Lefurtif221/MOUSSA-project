param(
  [Parameter(Mandatory=$true)][string]$Path
)
$override = @'

  /* === NDOKET : plein ecran (phone only) === */
  html,body{height:100%;}
  body{padding:0 !important;display:block !important;justify-content:flex-start !important;}
  .phone{width:100% !important;height:100% !important;max-width:none !important;
    border-radius:0 !important;border:none !important;box-shadow:none !important;}
  .notch{display:none !important;}
  .screen{height:100% !important;min-height:100dvh !important;}
  .content{overflow-y:auto !important;}
'@
$c = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
if($c -match 'NDOK: plein ecran'){ Write-Host "deja ok -> $Path"; return }
$c = $c -replace '</style>', ($override + "`n</style>")
[System.IO.File]::WriteAllText((Resolve-Path $Path), $c, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "fixed -> $Path"
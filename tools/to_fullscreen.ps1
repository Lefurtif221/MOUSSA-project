param(
  [Parameter(Mandatory=$true)][string]$Src,
  [Parameter(Mandatory=$true)][string]$Out
)
$c = Get-Content -LiteralPath $Src -Raw -Encoding UTF8

# CSS override block appended before the closing </style>
$override = @'

  /* === NDOKET : plein écran (hors maquette) === */
  html,body{height:100%;}
  body{padding:0 !important;display:block !important;justify-content:flex-start !important;}
  .phone{width:100% !important;height:100% !important;max-width:none !important;
    border-radius:0 !important;border:none !important;box-shadow:none !important;}
  .notch{display:none !important;}
  .screen{height:100% !important;min-height:100dvh !important;}
  .content{overflow-y:auto !important;}
'@

$c = $c -replace '</style>', ($override + "`n</style>")
Set-Content -LiteralPath $Out -Value $c -Encoding UTF8
Write-Host "OK -> $Out"
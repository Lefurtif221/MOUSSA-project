# Fix : attributs data-nav mal placés + injection nav.js avec \n littéral
$files = Get-ChildItem 'src\web\*.html'
$fixed = 0
foreach($f in $files){
  $p = $f.FullName
  $c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
  $orig = $c

  # 1. data-nav placé comme texte après '>' -> remettre dans la balise ouvrante
  $c = [regex]::Replace($c, '> data-nav="([^"]+)"', ' data-nav="$1">')

  # 2. \n littéral dans l'injection script
  if($c.Contains('</script>`n</body>')){
    $c = $c.Replace('</script>`n</body>', "</script>`n</body>")
  }

  if($c -ne $orig){
    [System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "FIXE $($f.Name)"
    $fixed++
  }
}
Write-Output "Total fixe: $fixed"
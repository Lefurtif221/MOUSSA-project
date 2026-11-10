function AddNavOpen($name, $dest) {
    $p = "src\web\$name.html"
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $p))
    $c = [System.Text.Encoding]::UTF8.GetString($bytes)
    $c = [regex]::Replace($c, '\<div class="btn-primary"\>', '<div class="btn-primary" data-nav="' + $dest + '">')
    [System.IO.File]::WriteAllText((Resolve-Path $p), $c, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "OK $name -> $dest"
}

AddNavOpen 'inscription_email'  'inscription_profil'
AddNavOpen 'fiche_apropos'      'fiche_services'
AddNavOpen 'fiche_avis'         'fiche_services'
AddNavOpen 'fiche_services'     'personnalisation'
AddNavOpen 'personnalisation'   'choix_mode'
AddNavOpen 'choix_mode'         'choix_creneau'
AddNavOpen 'choix_creneau'      'paiement'
AddNavOpen 'paiement'           'mes_reservations'
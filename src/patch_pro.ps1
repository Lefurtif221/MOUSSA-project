function Patch($file, $find, $insert) {
    $p = (Resolve-Path "src\web\$file.html").Path
    $c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
    $idx = $c.IndexOf($find)
    if ($idx -lt 0) { Write-Output "WARN $file"; return }
    $c = $c.Insert($idx + $find.IndexOf('>') + 1, $insert)
    [System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "OK $file"
}

$e = [char]0xE9   # é

# verification_securite : bouton Envoyer pour v[e]rification
Patch 'verification_securite' ('<div class="btn-primary disabled">') ' data-nav="attente_validation"'

# accueil_prestataire : action cards + tab accueil (regex sans accents)
$p = (Resolve-Path 'src\web\accueil_prestataire.html').Path
$c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
$c = [regex]::Replace($c, '(<div class="action-label">)Ajouter<br/>un service(</div>)', '<div class="action-label" data-nav="fixer_prix">Ajouter<br/>un service</div>')
$c = [regex]::Replace($c, '(<div class="action-label">)Voir mon<br/>agenda(</div>)', '<div class="action-label" data-nav="fiche_client">Voir mon<br/>agenda</div>')
$c = [regex]::Replace($c, '(<div class="tab active">)', '<div class="tab active" data-nav="accueil_prestataire">')
[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "OK accueil_prestataire"

# profil_prestataire : Compte de r[e]ception / Informations de l''[e]tablissement / Se d[e]connecter
$p = (Resolve-Path 'src\web\profil_prestataire.html').Path
$c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
$c = [regex]::Replace($c, ('(<div class="menu-text">)Compte de r' + $e + 'ception(</div>)'), ('<div class="menu-text" data-nav="moyens_paiement">Compte de r' + $e + 'ception</div>'))
$c = [regex]::Replace($c, ('(<div class="menu-text">)Informations de l\u2019' + $e + 'tablissement(</div>)'), ('<div class="menu-text" data-nav="mes_informations">Informations de l\u2019' + $e + 'tablissement</div>'))
$c = [regex]::Replace($c, ('(<div class="menu-text">)Se d' + $e + 'connecter(</div>)'), ('<div class="menu-text" data-nav="index">Se d' + $e + 'connecter</div>'))
[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "OK profil_prestataire"

# profil_client : Mes r[e]servations / Se d[e]connecter
$p = (Resolve-Path 'src\web\profil_client.html').Path
$c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
$c = [regex]::Replace($c, ('(<div class="menu-text">)Mes r' + $e + 'servations(</div>)'), ('<div class="menu-text" data-nav="mes_reservations">Mes r' + $e + 'servations</div>'))
$c = [regex]::Replace($c, ('(<div class="menu-text">)Se d' + $e + 'connecter(</div>)'), ('<div class="menu-text" data-nav="index">Se d' + $e + 'connecter</div>'))
[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "OK profil_client"

Write-Output "TERMINE"
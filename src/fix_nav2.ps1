foreach ($f in @('index', 'inscription_email')) {
    $p = (Resolve-Path "src\web\$f.html").Path
    $c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
    $c = [regex]::Replace($c, '<b>Se connecter</b data-nav="([^"]+)">', '<b data-nav="$1">Se connecter</b>')
    [System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "${f}: b fix done"
}

$p = (Resolve-Path "src\web\rendezvous_detail.html").Path
$c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
$c = [regex]::Replace($c, '\<div class="btn-cancel"\>', '<div class="btn-cancel" data-nav="mes_reservations">')
[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "rendezvous_detail: cancel fix done"
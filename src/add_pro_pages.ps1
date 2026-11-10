$ErrorActionPreference = 'Stop'

function Process-Page($src, $dest, $callbacks) {
    $p = (Resolve-Path $src).Path
    $out = "src\web\$dest.html"
    $c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))

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

    if (-not ($c -match 'nav\.js')) {
        $c = $c -replace '</body>', '<script src="nav.js"></script>`n</body>'
    }

    foreach ($cb in $callbacks) {
        $old = $cb[0]; $new = $cb[1]
        $c = [regex]::Replace($c, [regex]::Escape($old), $new)
    }

    [System.IO.File]::WriteAllText((Resolve-Path "src\web").Path + "\$dest.html", $c, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "OK -> $dest.html"
}

function Nav-once($file, $html, $dest) {
    $c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes((Resolve-Path "src\web\$file.html")))
    $idx = $c.IndexOf($html)
    if ($idx -lt 0) { Write-Output "WARN $file : introuvable [$html]"; return }
    $inject = $html.Substring(0, $html.IndexOf('>') + 1)
    $attr = ' data-nav="' + $dest + '"'
    $c = $c.Insert($idx + $inject.Length, $attr)
    [System.IO.File]::WriteAllText((Resolve-Path "src\web\$file.html"), $c, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "NAV $file <- $dest"
}

# ---------- 1. inscription : e-mail pro ----------
Process-Page 'creation_compte_email_prestataire ( valider ).html' 'inscription_email_pro' @(
)
Nav-once 'inscription_email_pro' '<div class="google-btn">' 'inscription_pro'
Nav-once 'inscription_email_pro' '<div class="btn-primary">Continuer</div>' 'inscription_pro'
Nav-once 'inscription_email_pro' '<b>Se connecter</b>' 'accueil_prestataire'

# ---------- 2. profil pro ----------
Process-Page 'inscription_prestataire ( valider ).html' 'inscription_pro' @(
)
Nav-once 'inscription_pro' '<div class="btn-primary">Continuer</div>' 'genre_prestataire'

# ---------- 3. genre ----------
Process-Page 'genre_prestataire ( valider ).html' 'genre_prestataire' @(
)
Nav-once 'genre_prestataire' '<div class="btn-primary">Continuer</div>' 'verification_securite'

# ---------- 5. sécurité ----------
Process-Page 'verification_securite ( validder ).html' 'verification_securite' @(
)
Nav-once 'verification_securite' '<div class="btn-primary disabled">Envoyer pour vérification</div>' 'attente_validation'

# ---------- attente validation ----------
Process-Page 'attente_validation ( valider ).html' 'attente_validation' @(
)
Nav-once 'attente_validation' '<div class="btn-secondary">Modifier mes documents</div>' 'verification_securite'

# ---------- accueil prestataire ----------
Process-Page 'accueil_prestataire ( valider ).html' 'accueil_prestataire' @(
)
Nav-once 'accueil_prestataire' '<div class="action-card"><div class="action-icon"></div><div class="action-label">Ajouter<br/>un service</div></div>' 'fixer_prix'
Nav-once 'accueil_prestataire' '<div class="action-card"><div class="action-icon"></div><div class="action-label">Voir mon<br/>agenda</div></div>' 'fiche_client'
Nav-once 'accueil_prestataire' '<span>Voir l''agenda</span>' 'fiche_client'
Nav-once 'accueil_prestataire' '<div class="tab active"><div class="icon-home"></div><div class="tab-text">Accueil</div></div>' 'accueil_prestataire'
Nav-once 'accueil_prestataire' '<div class="tab-text">Services</div>' 'fixer_prix'
Nav-once 'accueil_prestataire' '<div class="tab-text">RDV</div>' 'fiche_client'
Nav-once 'accueil_prestataire' '<div class="tab-text">Profil</div>' 'profil_prestataire'

# booking rows -> fiche_client (chaque occurrence)
$c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes((Resolve-Path 'src\web\accueil_prestataire.html')))
$c = [regex]::Replace($c, '(<div class="booking-row">)', '<div class="booking-row" data-nav="fiche_client">')
[System.IO.File]::WriteAllText((Resolve-Path 'src\web\accueil_prestataire.html'), $c, (New-Object System.Text.UTF8Encoding($false)))

# ---------- fiche client (détail RDV côté pro) ----------
Process-Page 'fiche_client (1).html' 'fiche_client' @(
)
Nav-once 'fiche_client' '<div class="btn-decline">Annuler le rendez-vous</div>' 'accueil_prestataire'

# ---------- fixer prix ----------
Process-Page 'fixer_prix ( valider ).html' 'fixer_prix' @(
)
Nav-once 'fixer_prix' '<div class="btn-primary">Enregistrer le service</div>' 'accueil_prestataire'

# ---------- profil prestataire ----------
Process-Page 'profil_prestataire (2).html' 'profil_prestataire' @(
)
Nav-once 'profil_prestataire' '<div class="menu-text">Mes services & prix</div>' 'fixer_prix'
Nav-once 'profil_prestataire' '<div class="menu-text">Mes revenus</div>' 'moyens_paiement'
Nav-once 'profil_prestataire' '<div class="menu-text">Compte de réception</div>' 'moyens_paiement'
Nav-once 'profil_prestataire' '<div class="menu-text">Informations de l''établissement</div>' 'mes_informations'
Nav-once 'profil_prestataire' '<div class="menu-text">Se déconnecter</div>' 'index'

# ---------- profil client ----------
Process-Page 'profil_client ( valider ).html' 'profil_client' @(
)
Nav-once 'profil_client' '<div class="menu-text">Mes réservations</div>' 'mes_reservations'
Nav-once 'profil_client' '<div class="menu-text">Mes favoris</div>' 'fiche_apropos'
Nav-once 'profil_client' '<div class="menu-text">Mes avis</div>' 'fiche_avis'
Nav-once 'profil_client' '<div class="menu-text">Mon compte</div>' 'mon_compte'
Nav-once 'profil_client' '<div class="menu-text">Moyens de paiement</div>' 'moyens_paiement'
Nav-once 'profil_client' '<div class="menu-text">Mes informations</div>' 'mes_informations'
Nav-once 'profil_client' '<div class="menu-text">Se déconnecter</div>' 'index'
$c = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes((Resolve-Path 'src\web\profil_client.html')))
$c = [regex]::Replace($c, '(<div class="become-provider">)', '<div class="become-provider" data-nav="inscription_email_pro">')
[System.IO.File]::WriteAllText((Resolve-Path 'src\web\profil_client.html'), $c, (New-Object System.Text.UTF8Encoding($false)))

# ---------- mon compte ----------
Process-Page 'mon_compte (2).html' 'mon_compte' @(
)

# ---------- moyens de paiement ----------
Process-Page 'moyens_paiement (1).html' 'moyens_paiement' @(
)

# ---------- mes informations ----------
Process-Page 'mes_informations.html' 'mes_informations' @(
)
Nav-once 'mes_informations' '<div class="btn-primary">Enregistrer</div>' 'profil_client'

Write-Output "----- TERMINE -----"
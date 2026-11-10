Set-Location (Join-Path $PSScriptRoot '..\src\web')
$enc = New-Object System.Text.UTF8Encoding($false)
$dq = [char]34
$sq = [char]39
$nl = "`n"

function Make-ImgLine($indent, $expr) {
  # $indent = e.g. "      "
  # returns: <indent>...innerHTML = '<img src="' + EXPR + '" alt="" style="..." />';
  $line = $indent + "document.getElementById('avatarLetter').innerHTML = " +
    $sq + "<img src=" + $dq + " + " + $expr + " + " + $dq + " alt=" + $dq + $dq +
    " style=" + $dq + "width:100%;height:100%;object-fit:cover;border-radius:inherit" + $dq + " />" + $sq + ";"
  return $line
}

# ---- accueil_client.html ----
$t = [IO.File]::ReadAllText('accueil_client.html')
$anchor = "      document.getElementById('avatarLetter').textContent = p.prenom[0].toUpperCase();"
if ($t.Contains($anchor)) {
  $add = $anchor + $nl +
    "      if(p.avatar_url){" + $nl +
    (Make-ImgLine "        " "p.avatar_url") + $nl +
    "      }"
  $t = $t.Replace($anchor, $add)
  [IO.File]::WriteAllText('accueil_client.html', $t, $enc)
  'CLIENT OK'
} else { 'CLIENT NOT FOUND' }

# ---- accueil_prestataire.html ----
$t = [IO.File]::ReadAllText('accueil_prestataire.html')
$a1 = "      document.getElementById('avatarLetter').textContent = (p.prenom||'N')[0].toUpperCase();"
if ($t.Contains($a1)) {
  $add1 = $a1 + $nl +
    "      if(p.avatar_url){" + $nl +
    (Make-ImgLine "        " "p.avatar_url") + $nl +
    "      }"
  $t = $t.Replace($a1, $add1)
  'PRO1 OK'
} else { 'PRO1 NOT FOUND' }

$a2 = "        document.getElementById('avatarLetter').textContent = (p.nom||'N')[0].toUpperCase();"
if ($t.Contains($a2)) {
  $add2 = $a2 + $nl +
    "        if(p.photo_url){" + $nl +
    (Make-ImgLine "          " "p.photo_url") + $nl +
    "        }"
  $t = $t.Replace($a2, $add2)
  'PRO2 OK'
} else { 'PRO2 NOT FOUND' }
[IO.File]::WriteAllText('accueil_prestataire.html', $t, $enc)

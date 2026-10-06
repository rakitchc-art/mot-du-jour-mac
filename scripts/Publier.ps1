<#
  Publie une version de Mot du jour. C'est le SEUL chemin de publication :
  jamais `gh release create` à la main (leçon de Kitch Projection, 31/08 :
  publiée sur le mauvais dépôt, la mise à jour n'est jamais arrivée).

  1. l'arbre est propre, et main est poussé ;
  2. la version est lue dans Ressources/Info.plist — ce que l'appli embarque ;
  3. les notes de version notes/vX.Y.Z.md existent ;
  4. l'étiquette n'existe ni ici ni sur GitHub : un numéro publié ne se
     republie jamais (deux personnes auraient deux applis sous le même numéro) ;
  5. aucune valeur du poste ne part (Verifier-Publication.ps1) ;
  6. pose l'étiquette et la pousse : les Mac de GitHub fabriquent, essaient
     sur quatre Mac, signent, publient, et l'appli juge elle-même la
     publication en ligne ;
  7. attend la fin, puis relit l'API PUBLIQUE sans jeton, comme l'appli la
     lira : le bon numéro et les trois pièces.

  Usage : powershell -File scripts\Publier.ps1
#>
$ErrorActionPreference = 'Stop'
$racine = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location $racine

function Lire-Plist {
    param([string]$Chemin, [string]$Cle)
    $reglages = New-Object Xml.XmlReaderSettings
    $reglages.DtdProcessing = [Xml.DtdProcessing]::Ignore
    $lecteur = [Xml.XmlReader]::Create($Chemin, $reglages)
    try { $doc = New-Object Xml.XmlDocument; $doc.Load($lecteur) } finally { $lecteur.Close() }
    $enfants = @($doc.plist.dict.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
    for ($i = 0; $i -lt $enfants.Count - 1; $i++) {
        if ($enfants[$i].Name -eq 'key' -and $enfants[$i].InnerText -eq $Cle) { return $enfants[$i + 1].InnerText }
    }
    throw "Clé absente d'Info.plist : $Cle"
}

# 1. L'arbre propre et poussé.
$sale = git status --porcelain
if ($sale) { throw "L'arbre n'est pas propre — committer d'abord :`n$($sale -join "`n")" }
git fetch -q origin
$ici = git rev-parse HEAD
$labas = git rev-parse origin/main
if ($ici -ne $labas) { throw "main n'est pas poussé (ici $ici, sur GitHub $labas)." }

# 2. La version, et l'adresse que l'appli interroge.
$plist = Join-Path $racine 'Ressources\Info.plist'
$version = Lire-Plist $plist 'CFBundleShortVersionString'
$adresse = Lire-Plist $plist 'MDJMiseAJourURL'
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Version illisible dans Info.plist : « $version »" }
$tag = "v$version"

# 3. Les notes.
$notes = Join-Path $racine "notes\$tag.md"
if (-not (Test-Path -LiteralPath $notes)) { throw "Les notes de version manquent : notes\$tag.md" }

# 4. Jamais deux fois le même numéro.
if (git tag -l $tag) { throw "L'étiquette $tag existe déjà ici : monter la version dans Info.plist." }
if (git ls-remote --tags origin "refs/tags/$tag") { throw "L'étiquette $tag existe déjà sur GitHub : monter la version." }

# 5. Rien du poste.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Verifier-Publication.ps1')
if ($LASTEXITCODE -ne 0) { throw "Verifier-Publication a trouvé une fuite : rien n'est publié." }

# 6. L'étiquette.
git tag -a $tag -m "Mot du jour $version"
git push -q origin $tag
"Étiquette $tag posée et poussée. Les Mac de GitHub prennent le relais…"

# 7. Attendre le passage de l'étiquette, puis relire l'API publique sans jeton.
$id = $null
for ($i = 0; $i -lt 30 -and -not $id; $i++) {
    Start-Sleep -Seconds 4
    $runs = gh run list -R rakitchc-art/mot-du-jour-mac --limit 10 --json databaseId,headBranch | ConvertFrom-Json
    $id = ($runs | Where-Object { $_.headBranch -eq $tag } | Select-Object -First 1).databaseId
}
if (-not $id) { throw "Aucun passage n'a démarré pour $tag en deux minutes." }
"Passage $id en cours (fabrication, quatre Mac, publication)…"
gh run watch $id -R rakitchc-art/mot-du-jour-mac --interval 20 --exit-status *> $null
if ($LASTEXITCODE -ne 0) { throw "Le passage $id a échoué : la version $tag n'est PAS publiée (ou seulement en partie). Voir : gh run view $id -R rakitchc-art/mot-du-jour-mac" }

$pub = Invoke-RestMethod -Uri $adresse -Headers @{ 'User-Agent' = 'Publier.ps1'; 'Accept' = 'application/vnd.github+json' }
if ($pub.tag_name -ne $tag) { throw "L'API publique annonce « $($pub.tag_name) », pas $tag." }
$noms = @($pub.assets | ForEach-Object { $_.name })
foreach ($attendu in @('Mot-du-jour.dmg', "Mot-du-jour-$version.zip", "Mot-du-jour-$version.zip.sig")) {
    if ($noms -notcontains $attendu) { throw "La publication $tag n'a pas « $attendu » (pièces : $($noms -join ', '))." }
}
"PUBLIÉE : $tag, lue par l'API publique sans compte, avec ses trois pièces."
"Lien de téléchargement direct : https://github.com/rakitchc-art/mot-du-jour-mac/releases/latest/download/Mot-du-jour.dmg"

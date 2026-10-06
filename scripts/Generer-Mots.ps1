<#
  Génère les listes de mots de l'appli à partir de celles du mot mystère de
  TokenBar (serveur/mots-solutions.txt et serveur/mots-acceptes.txt) :

    Sources/MotDuJourCore/MotsLexique.swift       les solutions, et les essais
                                                  acceptés tirés de Lexique 3.83
                                                  — licence CC BY-SA 4.0
    Sources/MotDuJourCore/MotsGrammalecte.swift   les essais que Lexique ne
                                                  connaît pas (« alien »…),
                                                  tirés de Grammalecte — MPL 2.0

  POURQUOI DEUX FICHIERS : la liste des acceptés de TokenBar mêle les deux
  licences, et ses CREDITS.md prévoyaient le cas d'un dépôt public : « publier
  les deux parts séparément ». Ce dépôt est public (décision du 06/10/2026).
  Le partage se fait contre Lexique383.tsv lui-même : un mot accepté qui est
  une forme de Lexique va dans la part Lexique, les autres viennent de
  Grammalecte (c'est ainsi que TokenBar les a ajoutés).

  Les listes existent en DEUX exemplaires (TokenBar et ici) : ce script est la
  seule façon de les resynchroniser (Règle 15 du CDC). Il ne part jamais dans
  l'appli : c'est un outil de fabrication.

  ⚠️ La liste des SOLUTIONS fixe l'ordre de tous les mots à venir : y ajouter
  ou retirer un seul mot décale le mot de chaque jour, y compris celui
  d'aujourd'hui. Le script refuse donc de la changer sans -ChangerSolutions.
  Les mots ACCEPTÉS en essai, eux, se resynchronisent librement.

  Usage :
    powershell -File scripts\Generer-Mots.ps1
    powershell -File scripts\Generer-Mots.ps1 -Source <listes> -Lexique <Lexique383.tsv> [-ChangerSolutions]
#>
param(
    [string]$Source = (Join-Path $PSScriptRoot '..\..\token-bar\serveur'),
    [string]$Lexique = (Join-Path $env:TEMP 'Lexique383.tsv'),
    [switch]$ChangerSolutions
)
$ErrorActionPreference = 'Stop'
$dossierCible = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Sources\MotDuJourCore'))
$cibleLexique = Join-Path $dossierCible 'MotsLexique.swift'
$cibleGrammalecte = Join-Path $dossierCible 'MotsGrammalecte.swift'
$ancienUnique = Join-Path $dossierCible 'Mots.swift'   # le format du premier jet, un seul fichier

function Lire-Liste {
    param([string]$Chemin)
    if (-not (Test-Path -LiteralPath $Chemin)) { throw "Liste introuvable : $Chemin" }
    $mots = New-Object 'System.Collections.Generic.List[string]'
    foreach ($ligne in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Chemin).Path, [Text.Encoding]::UTF8)) {
        $m = $ligne.Trim().ToLowerInvariant()
        if ($m -cmatch '^[a-z]{5}$') { $mots.Add($m) }
    }
    return ,($mots.ToArray())
}

function Lire-Bloc {
    # Les mots d'un bloc « let <nom> = """ … """ » d'un fichier généré.
    param([string]$Texte, [string]$Nom)
    $m = [regex]::Match($Texte, '(?s)let ' + $Nom + ' = """\n(.*?)\n"""')
    if (-not $m.Success) { return $null }
    return ,@($m.Groups[1].Value -split "`n" | Where-Object { $_ })
}

function ConvertTo-SansAccent {
    # La même que Fabriquer-Liste-Mots.ps1 de TokenBar.
    param([string]$S)
    $d = $S.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne 'NonSpacingMark') { [void]$sb.Append($c) }
    }
    return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

$solutions = Lire-Liste (Join-Path $Source 'mots-solutions.txt')
$acceptes  = Lire-Liste (Join-Path $Source 'mots-acceptes.txt')
if ($solutions.Count -lt 50) { throw "Seulement $($solutions.Count) solutions : la liste est tronquée ou ce n'est pas le bon dossier." }

# --- la garde des solutions, AVANT toute écriture ------------------------------
$precedent = $null
foreach ($f in @($cibleLexique, $ancienUnique)) {
    if (Test-Path -LiteralPath $f) { $precedent = $f; break }
}
if ($precedent) {
    $anciennes = Lire-Bloc ([IO.File]::ReadAllText($precedent)) 'listeSolutionsBrut'
    if ($null -eq $anciennes) { throw "$precedent existe mais sa liste des solutions est illisible : le vérifier avant de régénérer." }
    if ((($anciennes -join ',') -cne ($solutions -join ',')) -and -not $ChangerSolutions) {
        throw ("La liste des SOLUTIONS a changé ({0} → {1} mots). Ça décalerait le mot de chaque jour, " +
               "y compris celui d'aujourd'hui. Si c'est voulu : relancer avec -ChangerSolutions, " +
               "puis régénérer les vecteurs (node scripts\generer-vecteurs.js).") -f $anciennes.Count, $solutions.Count
    }
}

# --- le partage Lexique / Grammalecte -------------------------------------------
if (-not (Test-Path -LiteralPath $Lexique)) {
    throw "Lexique383.tsv introuvable ($Lexique). Fabriquer-Liste-Mots.ps1 de TokenBar le télécharge dans TEMP ; sinon -Lexique <chemin>."
}
$formesLexique = New-Object 'System.Collections.Generic.HashSet[string]'
$lecteur = New-Object System.IO.StreamReader((Resolve-Path -LiteralPath $Lexique).Path, [Text.Encoding]::UTF8)
try {
    $entete = $lecteur.ReadLine().Split("`t")
    $iOrtho = [array]::IndexOf($entete, 'ortho')
    if ($iOrtho -lt 0) { throw "colonne « ortho » absente de Lexique : format changé ?" }
    while ($null -ne ($ligne = $lecteur.ReadLine())) {
        $c = $ligne.Split("`t")
        if ($c.Count -lt $entete.Count) { continue }        # le même filtre que TokenBar
        $ortho = $c[$iOrtho]
        if ($ortho.Length -ne 5) { continue }
        $mot = (ConvertTo-SansAccent $ortho).ToLowerInvariant()
        if ($mot -cmatch '^[a-z]{5}$') { [void]$formesLexique.Add($mot) }
    }
} finally { $lecteur.Close() }

$horsLexique = @($solutions | Where-Object { -not $formesLexique.Contains($_) })
if ($horsLexique.Count) { throw ("Des solutions ne sont pas des formes de Lexique : " + ($horsLexique -join ' ') + ". Le partage serait faux.") }

$deLexique = New-Object 'System.Collections.Generic.List[string]'
$deGrammalecte = New-Object 'System.Collections.Generic.List[string]'
foreach ($m in $acceptes) {
    if ($formesLexique.Contains($m)) { $deLexique.Add($m) } else { $deGrammalecte.Add($m) }
}

# --- l'écriture ---------------------------------------------------------------
$nl = "`n"
$alerte = "// ⚠️ L'ordre des mots du jour dépend de la liste des solutions ENTIÈRE :" + $nl +
          '// le script refuse de la changer sans -ChangerSolutions.' + $nl
$texteLexique =
    '// Généré par scripts/Generer-Mots.ps1 — ne pas modifier à la main.' + $nl +
    '//' + $nl +
    '// Mots tirés de Lexique 3.83 (Boris New et Christophe Pallier — CNRS,' + $nl +
    '// Université Aix-Marseille, http://www.lexique.org), choisis pour le mot' + $nl +
    '// mystère de TokenBar : cinq lettres, sans accent ni majuscule ; les' + $nl +
    '// solutions sont les formes de base courantes, moins des exclusions relues' + $nl +
    '// à la main (voir CREDITS.md).' + $nl +
    '//' + $nl +
    '// Licence de CE FICHIER : Creative Commons BY-SA 4.0' + $nl +
    '// (https://creativecommons.org/licenses/by-sa/4.0/).' + $nl +
    ('// {0} solutions, {1} mots acceptés en essai.' -f $solutions.Count, $deLexique.Count) + $nl +
    '//' + $nl + $alerte + $nl +
    'let listeSolutionsBrut = """' + $nl + ($solutions -join $nl) + $nl + '"""' + $nl + $nl +
    'let listeAcceptesLexiqueBrut = """' + $nl + ($deLexique -join $nl) + $nl + '"""' + $nl
$texteGrammalecte =
    '// This Source Code Form is subject to the terms of the Mozilla Public' + $nl +
    '// License, v. 2.0. If a copy of the MPL was not distributed with this' + $nl +
    '// file, You can obtain one at http://mozilla.org/MPL/2.0/.' + $nl +
    '//' + $nl +
    '// Généré par scripts/Generer-Mots.ps1 — ne pas modifier à la main.' + $nl +
    '//' + $nl +
    '// Les formes de cinq lettres que Lexique 3.83 ne connaît pas, tirées du' + $nl +
    '// lexique des formes fléchies de Grammalecte v7.7 (Olivier R., base' + $nl +
    '// Dicollecte, https://grammalecte.net), sans accent ni majuscule.' + $nl +
    '// Acceptées en essai, jamais solutions.' + $nl +
    ('// {0} mots.' -f $deGrammalecte.Count) + $nl + $nl +
    'let listeAcceptesGrammalecteBrut = """' + $nl + ($deGrammalecte -join $nl) + $nl + '"""' + $nl

$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText($cibleLexique, $texteLexique, $utf8)
[IO.File]::WriteAllText($cibleGrammalecte, $texteGrammalecte, $utf8)

# L'effet, pas le code de retour : on relit ce qui a été écrit.
$reluL = [IO.File]::ReadAllText($cibleLexique)
$reluG = [IO.File]::ReadAllText($cibleGrammalecte)
$nSol = (Lire-Bloc $reluL 'listeSolutionsBrut').Count
$nLex = (Lire-Bloc $reluL 'listeAcceptesLexiqueBrut').Count
$nGra = (Lire-Bloc $reluG 'listeAcceptesGrammalecteBrut').Count
if ($nSol -ne $solutions.Count -or ($nLex + $nGra) -ne $acceptes.Count) {
    throw "Relecture : $nSol solutions et $($nLex + $nGra) acceptés écrits, attendu $($solutions.Count) et $($acceptes.Count)."
}
if (Test-Path -LiteralPath $ancienUnique) { Remove-Item -LiteralPath $ancienUnique }
"Écrit : $nSol solutions ; acceptés : $nLex de Lexique + $nGra de Grammalecte = $($nLex + $nGra)."

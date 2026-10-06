<#
  Avant chaque envoi sur GitHub (dépôt PUBLIC) : aucune valeur du poste de dev
  ne doit partir — nom d'utilisateur Windows, nom de la machine, chemin du
  dossier personnel, adresses des serveurs (Règles 10 et 12 du CDC).

  Les valeurs cherchées sont LUES sur la machine (variables d'environnement,
  ~/.ssh/config), jamais écrites ici : ce fichier est public, il ne doit pas
  être lui-même la fuite.

  Usage :
    powershell -File scripts\Verifier-Publication.ps1            (0 = propre)
    powershell -File scripts\Verifier-Publication.ps1 -Eprouver  (prouve qu'il sait rougir)
#>
param([switch]$Eprouver)
$ErrorActionPreference = 'Stop'
$racine = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Get-ValeursInterdites {
    $v = New-Object 'System.Collections.Generic.List[string]'
    foreach ($x in @($env:USERNAME, $env:COMPUTERNAME, $HOME)) { if ($x -and $x.Length -ge 4) { $v.Add($x) } }
    $config = Join-Path $HOME '.ssh\config'
    if (Test-Path -LiteralPath $config) {
        foreach ($ligne in [IO.File]::ReadAllLines($config)) {
            if ($ligne -match '^\s*HostName\s+(\S+)') { $v.Add($Matches[1]) }
        }
    }
    return ,($v.ToArray() | Select-Object -Unique)
}

function Find-Fuites {
    # Les lignes de $Fichiers qui contiennent une des $Valeurs (casse exacte).
    param([string[]]$Fichiers, [string[]]$Valeurs)
    $trouve = New-Object 'System.Collections.Generic.List[string]'
    foreach ($f in $Fichiers) {
        $chemin = Join-Path $racine $f
        if (-not (Test-Path -LiteralPath $chemin -PathType Leaf)) { $chemin = $f }
        if (-not (Test-Path -LiteralPath $chemin -PathType Leaf)) { continue }
        $n = 0
        foreach ($ligne in [IO.File]::ReadAllLines($chemin)) {
            $n++
            foreach ($val in $Valeurs) {
                if ($ligne.Contains($val)) { $trouve.Add(('{0}:{1} contient une valeur du poste ({2}…)' -f $f, $n, $val.Substring(0, 3))) }
            }
        }
    }
    return ,($trouve.ToArray())
}

$valeurs = Get-ValeursInterdites
if ($valeurs.Count -lt 3) { throw "Seulement $($valeurs.Count) valeurs à chercher : l'environnement ne ressemble pas au poste de dev, le contrôle ne prouverait rien." }

if ($Eprouver) {
    # Le levier : un faux fichier qui contient le nom d'utilisateur DOIT être pris.
    $leurre = Join-Path $env:TEMP ('mdj-leurre-' + [guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($leurre, "chemin : C:\Users\$($env:USERNAME)\cc`n")
    try {
        $pris = Find-Fuites @($leurre) $valeurs
        if ($pris.Count -eq 0) { throw "ÉPREUVE RATÉE : le contrôle n'a pas vu le leurre, il ne sait pas rougir." }
        "Épreuve réussie : le leurre est pris ($($pris.Count) ligne)."
    } finally { Remove-Item -LiteralPath $leurre -ErrorAction SilentlyContinue }
    return
}

Push-Location $racine
try {
    $suivis = @(git ls-files --cached --others --exclude-standard)
} finally { Pop-Location }
if ($suivis.Count -lt 10) { throw "Seulement $($suivis.Count) fichiers à relire : ce n'est pas le bon dossier." }
$fuites = Find-Fuites $suivis $valeurs
if ($fuites.Count) {
    $fuites | ForEach-Object { "  ✗ $_" }
    throw "$($fuites.Count) fuite(s) : rien ne part tant qu'elles sont là."
}
"Publication propre : $($suivis.Count) fichiers relus, $($valeurs.Count) valeurs du poste cherchées, 0 trouvée."

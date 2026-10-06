<#
  Éprouve, sur ce PC (Node suffit), les outils de fabrication écrits en
  JavaScript, par leur EFFET :
   - creer-cle.js refuse d'écraser une clé ;
   - signer-archive.js écrit un .sig qui se vérifie avec la bonne clé, et
     N'ÉCRIT RIEN avec une clé publique qui ne va pas (ou illisible) ;
   - serveur-epreuve.js sert un fichier, refuse la remontée de dossier, et
     survit à un « % » mal formé.
  Usage : powershell -File scripts\Eprouver-Outils.ps1
#>
# Pas « Stop » : sous Windows PowerShell 5.1, ce que Node écrit sur sa sortie
# d'erreur (les refus ATTENDUS de ce banc) deviendrait une exception. Chaque
# contrôle juge par le code de sortie et par l'effet sur le disque.
$ErrorActionPreference = 'Continue'
$scripts = Split-Path -Parent $MyInvocation.MyCommand.Path
$tmp = Join-Path $env:TEMP ('mdj-outils-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp | Out-Null
$echecs = 0
function Verifier([bool]$Condition, [string]$Quoi) {
    if ($Condition) { "  ✓ $Quoi" } else { "  ✗ $Quoi"; $script:echecs++ }
}
try {
    # --- les clés ---
    node (Join-Path $scripts 'creer-cle.js') (Join-Path $tmp 'cle') | Out-Null
    Verifier ($LASTEXITCODE -eq 0) 'creer-cle.js fabrique une paire'
    node (Join-Path $scripts 'creer-cle.js') (Join-Path $tmp 'cle') 2>$null | Out-Null
    Verifier ($LASTEXITCODE -ne 0) 'creer-cle.js refuse d''écraser une clé existante'
    node (Join-Path $scripts 'creer-cle.js') (Join-Path $tmp 'autre') | Out-Null
    $bonne = (Get-Content -Raw (Join-Path $tmp 'cle\cle-maj-publique.txt')).Trim()
    $autre = (Get-Content -Raw (Join-Path $tmp 'autre\cle-maj-publique.txt')).Trim()

    # --- la signature ---
    $archive = Join-Path $tmp 'archive.zip'
    [IO.File]::WriteAllBytes($archive, [byte[]](1..200))
    node (Join-Path $scripts 'signer-archive.js') $archive (Join-Path $tmp 'cle\cle-maj-privee.pem') $bonne | Out-Null
    Verifier ($LASTEXITCODE -eq 0 -and (Test-Path "$archive.sig")) 'signée avec la bonne clé : .sig écrit'
    Remove-Item "$archive.sig"
    node (Join-Path $scripts 'signer-archive.js') $archive (Join-Path $tmp 'cle\cle-maj-privee.pem') $autre 2>$null | Out-Null
    Verifier ($LASTEXITCODE -ne 0 -and -not (Test-Path "$archive.sig")) 'clé publique qui ne va pas : refus, AUCUN .sig'
    node (Join-Path $scripts 'signer-archive.js') $archive (Join-Path $tmp 'cle\cle-maj-privee.pem') 'pas-une-cle' 2>$null | Out-Null
    Verifier ($LASTEXITCODE -ne 0 -and -not (Test-Path "$archive.sig")) 'clé publique illisible : refus, AUCUN .sig'

    # --- le serveur d'épreuve ---
    $serv = Join-Path $tmp 'serveur'
    New-Item -ItemType Directory $serv | Out-Null
    Set-Content -Path (Join-Path $serv 'a.json') -Value '{"ok":true}' -Encoding ASCII
    $port = 18765
    $proc = Start-Process node -ArgumentList @((Join-Path $scripts 'serveur-epreuve.js'), $serv, $port) -PassThru -WindowStyle Hidden
    try {
        $pret = $false
        for ($i = 0; $i -lt 30 -and -not $pret; $i++) {
            try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$port/a.json" -TimeoutSec 2 | Out-Null; $pret = $true } catch { Start-Sleep -Milliseconds 300 }
        }
        Verifier $pret 'le serveur sert un fichier'
        function Code([string]$Chemin) {
            try { return [int](Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$port$Chemin" -TimeoutSec 3).StatusCode }
            catch { if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode } ; return -1 }
        }
        Verifier ((Code '/%E0%A4%A') -eq 400) '« % » mal formé : 400'
        Verifier ((Code '/a.json') -eq 200) '… et le serveur répond toujours'
        Verifier ((Code '/..%2f..%2fWindows%2fwin.ini') -in @(403, 404)) 'remontée de dossier : refusée'
    } finally {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
if ($echecs) { throw "$echecs contrôle(s) en échec" }
'Outils éprouvés : tout est vert.'

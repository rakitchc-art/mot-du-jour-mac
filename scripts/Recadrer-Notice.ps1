<#
  Recadre les photos d'écran prises sur les Mac de GitHub (captures-notice.sh,
  autotest.sh) pour la notice d'installation : docs/images/.

  Les cadres valent pour des écrans de 1024 × 768 (macos-15 et macos-26) et
  pour la mise en page du .dmg de mettre-en-page-dmg.applescript. Si l'une
  bouge, les images seront mal cadrées : les REGARDER après chaque passage.

  Usage :
    powershell -File scripts\Recadrer-Notice.ps1 -Mac26 <pièce jointe essais-macos-26> -Mac15 <essais-macos-15>
#>
param(
    [Parameter(Mandatory = $true)][string]$Mac26,
    [Parameter(Mandatory = $true)][string]$Mac15,
    [string]$Dest = ''
)
$ErrorActionPreference = 'Stop'
# (Pas de $PSScriptRoot dans la valeur par défaut d'un paramètre : vide ici
# sous Windows PowerShell 5.1, mesuré le 06/10.)
if (-not $Dest) { $Dest = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\docs\images' }
Add-Type -AssemblyName System.Drawing

$coupes = @(
    @{ Source = (Join-Path $Mac26 'notice\1-dmg-ouvert.png');          Sortie = '1-glisser.png';              X = 200; Y = 120; L = 540; H = 340 },
    @{ Source = (Join-Path $Mac26 'notice\2-avertissement.png');       Sortie = '2-avertissement-26.png';     X = 376; Y = 122; L = 272; H = 297 },
    @{ Source = (Join-Path $Mac15 'notice\2-avertissement.png');       Sortie = '2-avertissement-15.png';     X = 375; Y = 131; L = 274; H = 246 },
    @{ Source = (Join-Path $Mac26 'notice\3-reglages.png');            Sortie = '3-ouvrir-quand-meme.png';    X = 424; Y = 372; L = 558; H = 176 },
    @{ Source = (Join-Path $Mac26 'captures\ecran-panneau-ouvert.png'); Sortie = '4-pret.png';                X = 600; Y = 0;   L = 424; H = 448 }
)

$destComplet = [IO.Path]::GetFullPath($Dest)
New-Item -ItemType Directory -Force $destComplet | Out-Null
foreach ($c in $coupes) {
    if (-not (Test-Path -LiteralPath $c.Source)) { throw "Photo introuvable : $($c.Source)" }
    $image = [Drawing.Image]::FromFile([IO.Path]::GetFullPath($c.Source))
    try {
        if ($image.Width -ne 1024 -or $image.Height -ne 768) {
            throw "$($c.Source) fait $($image.Width) × $($image.Height), pas 1024 × 768 : les cadres ne valent plus."
        }
        $coupe = New-Object Drawing.Bitmap $c.L, $c.H
        $g = [Drawing.Graphics]::FromImage($coupe)
        try {
            $g.DrawImage($image, (New-Object Drawing.Rectangle 0, 0, $c.L, $c.H),
                         (New-Object Drawing.Rectangle $c.X, $c.Y, $c.L, $c.H), [Drawing.GraphicsUnit]::Pixel)
        } finally { $g.Dispose() }
        $sortie = Join-Path $destComplet $c.Sortie
        $coupe.Save($sortie, [Drawing.Imaging.ImageFormat]::Png)
        $coupe.Dispose()
        "écrit : $($c.Sortie) ($($c.L) × $($c.H))"
    } finally { $image.Dispose() }
}

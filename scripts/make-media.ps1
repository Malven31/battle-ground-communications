# Writes BGComs' wheel textures into BGComs/media/:
#   softline.tga      8x32: a line's cross-section, a soft bell across the height (Line regions
#                     stretch a texture along their length, so the height runs across the line). White.
#   glow.tga          64x64: a round soft glow, opaque in the middle and fading to nothing at the edge. White.
#   pill.tga          32x32: a rounded rectangle, white; Wheel.lua cuts it in three so its ends keep
#                     their shape. The white ones are tinted in the game (SetVertexColor).
#   disc.tga          512x512: the wheel's dark disc, its rim and its six dividers.
#   wedge.tga         256x256: the gold glow of a selected wedge, pointing right; the game turns it.
#   icon-<call>.tga   128x128: the icons of INC, SPOTTED, HELP, OMW and CLEAR.
#   flag-red.tga, flag-blue.tga  128x128: EFC's icon, the enemy's flag (red: Horde, blue: Alliance).
# The disc, the wedge and the icons come from wheel-art.ps1, the drawing the gallery uses too.
#
#   powershell -File scripts/make-media.ps1
#
# Uncompressed 32-bit BGRA TGA, bottom-up rows, power-of-two sizes (what WoW reads as an addon texture).
param([string]$Dir = (Join-Path $PSScriptRoot '..\BGComs\media'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wheel-art.ps1')
if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Force $Dir | Out-Null }

function Write-TgaFile([string]$path, [int]$w, [int]$h, [byte[]]$pixels) {
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = $w -band 0xFF; $header[13] = $w -shr 8
    $header[14] = $h -band 0xFF; $header[15] = $h -shr 8
    $header[16] = 32
    $header[17] = 8          # 8 alpha bits, bottom-left origin
    $stream = [System.IO.File]::Create($path)
    try { $stream.Write($header, 0, 18); $stream.Write($pixels, 0, $pixels.Length) } finally { $stream.Dispose() }
    Write-Output "$path ($w x $h)"
}

# A white texture shaped by alpha: $alphaAt gives 0..1 for (column, row), bottom row first.
function Write-AlphaTga([string]$name, [int]$w, [int]$h, [scriptblock]$alphaAt) {
    $pixels = New-Object byte[] ($w * $h * 4)
    $i = 0
    for ($row = 0; $row -lt $h; $row++) {
        for ($col = 0; $col -lt $w; $col++) {
            $a = & $alphaAt $col $row
            $a = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($a * 255)))
            $pixels[$i] = 255; $pixels[$i + 1] = 255; $pixels[$i + 2] = 255; $pixels[$i + 3] = [byte]$a
            $i += 4
        }
    }
    Write-TgaFile (Join-Path $Dir $name) $w $h $pixels
}

# A square, transparent drawing surface. (GDI+ stores fully transparent pixels as black, so soft
# edges darken a little when the game filters them; over the dark disc that doesn't show.)
function New-Texture([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear($C::Transparent)
    return @($bmp, $g)
}

# Saves a drawing as TGA: GDI+'s 32bppArgb rows are BGRA, top row first; TGA wants the bottom row first.
function Save-Texture($bmp, $g, [string]$name) {
    $g.Dispose()
    $w, $h = $bmp.Width, $bmp.Height
    $lock = $bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $w, $h), [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $stride = $lock.Stride
        $raw = New-Object byte[] ($stride * $h)
        [System.Runtime.InteropServices.Marshal]::Copy($lock.Scan0, $raw, 0, $raw.Length)
    } finally { $bmp.UnlockBits($lock) }
    $bmp.Dispose()
    $pixels = New-Object byte[] ($w * $h * 4)
    for ($row = 0; $row -lt $h; $row++) {
        [Array]::Copy($raw, ($h - 1 - $row) * $stride, $pixels, $row * $w * 4, $w * 4)
    }
    Write-TgaFile (Join-Path $Dir $name) $w $h $pixels
}

# The line: a raised-cosine bell across the height, full in the middle third, zero at the edges.
Write-AlphaTga 'softline.tga' 8 32 {
    param($col, $row)
    $t = [Math]::Abs((($row + 0.5) / 32) * 2 - 1)   # 0 in the middle, 1 at the edges
    if ($t -lt 0.3) { return 1.0 }
    $u = ($t - 0.3) / 0.7
    return 0.5 + 0.5 * [Math]::Cos([Math]::PI * $u)
}

# The glow: a smooth falloff from the centre to the rim.
Write-AlphaTga 'glow.tga' 64 64 {
    param($col, $row)
    $dx = (($col + 0.5) / 64) * 2 - 1
    $dy = (($row + 0.5) / 64) * 2 - 1
    $r = [Math]::Sqrt($dx * $dx + $dy * $dy)
    if ($r -ge 1) { return 0.0 }
    $v = 0.5 + 0.5 * [Math]::Cos([Math]::PI * $r)
    return $v * $v
}

# The pill: a rounded rectangle with a 1 px clear border (so its edges are smoothed too) and
# corners a quarter of its height.
Write-AlphaTga 'pill.tga' 32 32 {
    param($col, $row)
    $r = 7.5
    $x = $col + 0.5; $y = $row + 0.5
    $dx = [Math]::Max([Math]::Max((1 + $r) - $x, $x - (31 - $r)), 0)
    $dy = [Math]::Max([Math]::Max((1 + $r) - $y, $y - (31 - $r)), 0)
    $edge = [Math]::Sqrt($dx * $dx + $dy * $dy) - $r   # negative inside
    return [Math]::Max(0.0, [Math]::Min(1.0, 0.5 - $edge))
}

# The disc and the wedge are shown at Wheel.lua's ART units square: the disc and 4 units around it.
$ART = 2 * ($DISC + 4)

$bmp, $g = New-Texture 512
Draw-Disc $g 256 256 (512 / $ART)
Save-Texture $bmp $g 'disc.tga'

# Centred like the disc, so turning it about its centre turns it about the wheel's.
$bmp, $g = New-Texture 256
Draw-Wedge $g 128 128 (256 / $ART) -30 30
Save-Texture $bmp $g 'wedge.tga'

# Each icon fills 1/1.5 of its texture (Wheel.lua shows the texture at 1.5 times the icon's size).
$ICON_PX = 128
foreach ($kind in @('inc', 'spotted', 'help', 'omw', 'clear')) {
    $bmp, $g = New-Texture $ICON_PX
    Draw-CallIcon $g $kind ($ICON_PX / 2) ($ICON_PX / 2) ($ICON_PX / 1.5)
    Save-Texture $bmp $g "icon-$kind.tga"
}
foreach ($flag in @(@('flag-red.tga', $FLAG_RED), @('flag-blue.tga', $FLAG_BLUE))) {
    $bmp, $g = New-Texture $ICON_PX
    Draw-CallIcon $g 'efc' ($ICON_PX / 2) ($ICON_PX / 2) ($ICON_PX / 1.5) 255 $flag[1]
    Save-Texture $bmp $g $flag[0]
}

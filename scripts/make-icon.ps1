# Draws BGComs' icon: a walkie-talkie in front of two crossed flags, blue on the left and red on the
# right, with signal waves from its antenna.
#
#   powershell -File scripts/make-icon.ps1 -Out BGComs/media/icon.tga -Size 64   # in-game icon
#   powershell -File scripts/make-icon.ps1 -Out curseforge/logo.png -Size 512    # CurseForge avatar
#
# Same method as Gear Set Colors' make-icon.ps1: drawn at four times the size and scaled down, shapes in
# units (0 to 1 across the icon). A .tga is written as uncompressed 32-bit BGRA with bottom-up rows, which
# WoW reads as an addon texture (its size must be a power of two). Any other extension is written as PNG.
param([Parameter(Mandatory)][string]$Out, [int]$Size = 512)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$C = [System.Drawing.Color]
$S = $Size * 4

function Hex([string]$hex, [int]$alpha = 255) {
    $v = [Convert]::ToInt32($hex.TrimStart('#'), 16)
    return $C::FromArgb($alpha, ($v -shr 16) -band 255, ($v -shr 8) -band 255, $v -band 255)
}
function Pt([double]$x, [double]$y) { New-Object System.Drawing.PointF ([single]$x), ([single]$y) }
function RectF([double]$x, [double]$y, [double]$w, [double]$h) {
    New-Object System.Drawing.RectangleF ([single]$x), ([single]$y), ([single]$w), ([single]$h)
}
function Ellipse([double]$cx, [double]$cy, [double]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse((RectF ($cx - $r) ($cy - $r) ($r * 2) ($r * 2)))
    return $path
}
function RoundedRect([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
    $d = $r * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc((RectF $x $y $d $d), 180, 90)
    $path.AddArc((RectF ($x + $w - $d) $y $d $d), 270, 90)
    $path.AddArc((RectF ($x + $w - $d) ($y + $h - $d) $d $d), 0, 90)
    $path.AddArc((RectF $x ($y + $h - $d) $d $d), 90, 90)
    $path.CloseFigure()
    return $path
}
function GradientBrush($rect, [double]$angle, [System.Drawing.Color[]]$colors, [single[]]$positions) {
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $colors[0], $colors[-1], ([single]$angle)
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend
    $blend.Colors = $colors
    $blend.Positions = $positions
    $brush.InterpolationColors = $blend
    return $brush
}
function Solid([System.Drawing.Color]$color) { New-Object System.Drawing.SolidBrush $color }

# Icon units to pixels, optionally rotated by $angle degrees about ($px, $py) and mirrored left-right
# about x = $px.
function Units([double]$angle = 0, [double]$px = 0.5, [double]$py = 0.5, [switch]$Mirror, [double]$dx = 0, [double]$dy = 0, [double]$k = 1) {
    $m = New-Object System.Drawing.Drawing2D.Matrix
    $m.Scale($S, $S)
    if ($dx -or $dy) { $m.Translate($dx, $dy) }
    if ($k -ne 1) {
        # Shrink by $k about ($px, $py).
        $m.Translate($px, $py)
        $m.Scale($k, $k)
        $m.Translate(-$px, -$py)
    }
    if ($angle) { $m.RotateAt($angle, (Pt $px $py)) }
    if ($Mirror) {
        $m.Translate($px, 0)
        $m.Scale(-1, 1)
        $m.Translate(-$px, 0)
    }
    return $m
}

$big = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($big)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

# --- Background: dark slate, lighter in the middle. ---
$g.Transform = Units
$g.FillRectangle((Solid (Hex '0b0d12')), (RectF 0 0 1 1))
$glowPath = Ellipse 0.5 0.5 0.75
$glow = New-Object System.Drawing.Drawing2D.PathGradientBrush $glowPath
$glow.CenterColor = Hex '2f3646'
$glow.SurroundColors = @((Hex '0b0d12'))
$g.FillPath($glow, $glowPath)

# A strip of light across the middle: a wide soft streak, and a thinner brighter core.
function Streak([double]$rx, [double]$ry, [System.Drawing.Color]$center) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse((RectF (0.5 - $rx) (0.5 - $ry) ($rx * 2) ($ry * 2)))
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $brush.CenterColor = $center
    $brush.SurroundColors = @($C::FromArgb(0, $center.R, $center.G, $center.B))
    $g.FillPath($brush, $path)
}
Streak 0.62 0.075 (Hex '9fb8ff' 70)
Streak 0.55 0.014 (Hex 'e6eeff' 190)
Streak 0.3 0.005 (Hex 'ffffff' 230)

# --- A flag, drawn upright with its cloth to the right of the pole, then turned (and mirrored),
# shrunk towards where the poles cross so every flag stays inside the icon. ---
$flagScale = 0.84
function Flag([string]$light, [string]$mid, [string]$dark, [double]$angle, [switch]$Mirror) {
    $pivotX, $pivotY = 0.5, 0.8

    # The cloth: a waving banner hanging from the top of the pole, with a swallowtail end.
    $cloth = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cloth.AddLine((Pt 0.515 0.11), (Pt 0.515 0.38))
    $cloth.AddBezier((Pt 0.515 0.38), (Pt 0.60 0.41), (Pt 0.68 0.35), (Pt 0.80 0.39))
    $cloth.AddLine((Pt 0.80 0.39), (Pt 0.73 0.26))
    $cloth.AddLine((Pt 0.73 0.26), (Pt 0.81 0.135))
    $cloth.AddBezier((Pt 0.81 0.135), (Pt 0.69 0.09), (Pt 0.61 0.15), (Pt 0.515 0.11))
    $cloth.CloseFigure()
    $clothBrush = GradientBrush (RectF 0.5 0.08 0.33 0.34) 15 @((Hex $light), (Hex $mid), (Hex $dark)) @(0.0, 0.55, 1.0)

    # A fold: a darker band across the cloth.
    $fold = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fold.AddBezier((Pt 0.585 0.125), (Pt 0.63 0.20), (Pt 0.61 0.30), (Pt 0.63 0.39))
    $fold.AddLine((Pt 0.63 0.39), (Pt 0.67 0.375))
    $fold.AddBezier((Pt 0.67 0.375), (Pt 0.65 0.29), (Pt 0.67 0.20), (Pt 0.63 0.115))
    $fold.CloseFigure()

    $wood = GradientBrush (RectF 0.485 0 0.03 1) 0 @((Hex 'c98a4b'), (Hex '8a5427'), (Hex '4d2b12')) @(0.0, 0.5, 1.0)
    $gold = GradientBrush (RectF 0.46 0.02 0.08 0.08) 90 @((Hex 'fff0a8'), (Hex 'e2ac3f'), (Hex '9a671b')) @(0.0, 0.5, 1.0)
    $pole = RoundedRect 0.486 0.07 0.028 0.88 0.012
    $finial = Ellipse 0.5 0.065 0.032

    # Shadow first, then the flag.
    $g.Transform = Units $angle $pivotX $pivotY -Mirror:$Mirror 0.012 0.016 $flagScale
    $shadow = Solid ($C::FromArgb(120, 0, 0, 0))
    foreach ($p in @($cloth, $pole, $finial)) { $g.FillPath($shadow, $p) }
    $g.Transform = Units $angle $pivotX $pivotY -Mirror:$Mirror 0 0 $flagScale
    $g.FillPath($wood, $pole)
    $g.FillPath($clothBrush, $cloth)
    $g.FillPath((Solid (Hex '000000' 55)), $fold)
    $edge = New-Object System.Drawing.Pen ((Hex 'f0c35a' 220)), ([single]0.012)
    $edge.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($edge, $cloth)
    $g.FillPath($gold, $finial)
}

Flag '6f9cff' '2f5fd6' '18307a' -24 -Mirror   # blue, leaning left, cloth to the left
Flag 'ff7a6a' 'd23030' '701616' 24            # red, leaning right, cloth to the right

# --- The walkie-talkie, lifted off the background: a soft deep shadow, a faint light halo, and a
# light edge. ---
$bodyRect = RoundedRect 0.335 0.30 0.30 0.58 0.06
$antenna = RoundedRect 0.555 0.12 0.06 0.22 0.025
$antennaTip = Ellipse 0.585 0.13 0.032
$knob = RoundedRect 0.38 0.25 0.07 0.07 0.015
$sideButton = RoundedRect 0.315 0.44 0.03 0.16 0.012
$radioParts = @($bodyRect, $antenna, $antennaTip, $knob, $sideButton)

# The soft shadow: the radio's outline stroked wide and faint several times (a cheap blur), offset
# down and to the right.
$g.Transform = Units 0 0.5 0.5 -dx 0.022 -dy 0.03
foreach ($step in @(@(0.07, 28), @(0.05, 40), @(0.03, 60), @(0.012, 90))) {
    $pen = New-Object System.Drawing.Pen ($C::FromArgb($step[1], 0, 0, 0)), ([single]$step[0])
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    foreach ($p in $radioParts) { $g.DrawPath($pen, $p) }
}
foreach ($p in $radioParts) { $g.FillPath((Solid ($C::FromArgb(170, 0, 0, 0))), $p) }

# The halo: a faint cool light just around the body.
$g.Transform = Units
foreach ($step in @(@(0.05, 18), @(0.032, 30), @(0.018, 45))) {
    $pen = New-Object System.Drawing.Pen ((Hex 'b9cdf5' $step[1])), ([single]$step[0])
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $bodyRect)
}

$g.Transform = Units
$dark = GradientBrush (RectF 0.335 0 0.30 1) 0 @((Hex '5a6272'), (Hex '30353f'), (Hex '191c22')) @(0.0, 0.45, 1.0)
$antennaBrush = GradientBrush (RectF 0.555 0 0.06 1) 0 @((Hex '6b7383'), (Hex '2a2e36')) @(0.0, 1.0)
$g.FillPath($antennaBrush, $antenna)
$g.FillPath((Solid (Hex 'e04a3a')), $antennaTip)
$g.FillPath((Solid (Hex 'ffffff' 120)), (Ellipse 0.577 0.12 0.011))
$g.FillPath($antennaBrush, $knob)
$g.FillPath($antennaBrush, $sideButton)
$g.FillPath($dark, $bodyRect)

# A dark outline, a light edge just inside it, and a light rim on the body's face.
$outline = New-Object System.Drawing.Pen ((Hex '000000' 220)), ([single]0.012)
$g.DrawPath($outline, $bodyRect)
$edge = New-Object System.Drawing.Pen ((Hex 'd7e2f7' 150)), ([single]0.006)
$g.DrawPath($edge, (RoundedRect 0.339 0.304 0.292 0.572 0.057))
$rim = New-Object System.Drawing.Pen ((Hex 'ffffff' 60)), ([single]0.006)
$g.DrawPath($rim, (RoundedRect 0.348 0.313 0.274 0.554 0.05))

# The screen: glowing green, with a little signal-strength bars glyph.
$screen = RoundedRect 0.375 0.36 0.22 0.15 0.025
$g.FillPath((Solid (Hex '0d1a10')), (RoundedRect 0.368 0.353 0.234 0.164 0.03))
$g.FillPath((GradientBrush (RectF 0 0.36 1 0.15) 90 @((Hex 'c6ff9a'), (Hex '6ed24a'), (Hex '2f7a22')) @(0.0, 0.5, 1.0)), $screen)
$barBrush = Solid (Hex '1a3d14' 220)
$bars = @(@(0.405, 0.465, 0.025), @(0.44, 0.445, 0.045), @(0.475, 0.425, 0.065), @(0.51, 0.405, 0.085))
foreach ($b in $bars) { $g.FillPath($barBrush, (RoundedRect $b[0] $b[1] 0.022 $b[2] 0.006)) }
$g.FillPath((Solid (Hex 'ffffff' 70)), (RoundedRect 0.385 0.368 0.2 0.03 0.012))

# The speaker grille: rounded slits.
$slit = Solid (Hex '0c0e12')
$slitLight = Solid (Hex 'ffffff' 35)
for ($i = 0; $i -lt 5; $i++) {
    $y = 0.565 + $i * 0.052
    $g.FillPath($slit, (RoundedRect 0.38 $y 0.21 0.026 0.013))
    $g.FillPath($slitLight, (RoundedRect 0.385 ($y + 0.022) 0.2 0.006 0.003))
}

# A small red "talk" light.
$g.FillPath((Solid (Hex 'ff5a4a')), (Ellipse 0.6 0.335 0.012))

$g.Dispose()

# Scale down to the requested size.
$bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.DrawImage($big, (New-Object System.Drawing.Rectangle 0, 0, $Size, $Size))
$g.Dispose()
$big.Dispose()

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
if ($Out -match '\.tga$') {
    $lock = $bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $Size, $Size), [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $pixels = New-Object byte[] ($lock.Stride * $Size)
    [System.Runtime.InteropServices.Marshal]::Copy($lock.Scan0, $pixels, 0, $pixels.Length)
    $stride = $lock.Stride
    $bmp.UnlockBits($lock)
    $header = New-Object byte[] 18
    $header[2] = 2                                              # uncompressed true colour
    $header[12] = $Size -band 0xFF; $header[13] = $Size -shr 8  # width
    $header[14] = $Size -band 0xFF; $header[15] = $Size -shr 8  # height
    $header[16] = 32                                            # bits per pixel
    $header[17] = 8                                             # 8 alpha bits, bottom-left origin
    $stream = [System.IO.File]::Create($Out)
    try {
        $stream.Write($header, 0, 18)
        for ($row = $Size - 1; $row -ge 0; $row--) { $stream.Write($pixels, $row * $stride, $Size * 4) }  # BGRA, bottom row first
    } finally { $stream.Dispose() }
} else {
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
}
$bmp.Dispose()
Write-Output "$Out ($Size x $Size)"

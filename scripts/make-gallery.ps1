# Draws BGComs' CurseForge gallery illustrations (1280x720 PNG) into curseforge/gallery/:
#   1-map.png     the battlefield map (Arathi Basin) with the place codes BGComs draws
#   2-wheel.png   a middle-click near Gold Mine, dragged up three rings: "3 inc GM"
#   3-chat.png    the callouts as everyone reads them in battleground chat
#   4-calls.png   the six directions and the count rings
#
#   powershell -File scripts/make-gallery.ps1 -MapImage <Arathi Basin map art, 1002x668 PNG>
#
# These are drawn illustrations of the addon's layout (same directions, rings, codes and texts as the
# code), not game captures: in-game the wheel uses Blizzard's ping art. Replace them with real
# screenshots when there are some. No character names: the sender is "You".
param(
    # Arathi Basin's map art (map 1461), 1002x668, exported from the game files (wow.export: zone 3358).
    [Parameter(Mandatory)][string]$MapImage,
    [string]$OutDir = (Join-Path $PSScriptRoot '..\curseforge\gallery')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$C = [System.Drawing.Color]
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }

$W, $H = 1280, 720
$GOLD = $C::FromArgb(255, 255, 209, 0)
$FAMILY = New-Object System.Drawing.FontFamily 'Segoe UI'
$BOLD = [System.Drawing.FontStyle]::Bold

function Hex([string]$hex, [int]$alpha = 255) {
    $v = [Convert]::ToInt32($hex.TrimStart('#'), 16)
    return $C::FromArgb($alpha, ($v -shr 16) -band 255, ($v -shr 8) -band 255, $v -band 255)
}
function Pt([double]$x, [double]$y) { New-Object System.Drawing.PointF ([single]$x), ([single]$y) }
function RectF([double]$x, [double]$y, [double]$w, [double]$h) { New-Object System.Drawing.RectangleF ([single]$x), ([single]$y), ([single]$w), ([single]$h) }
function Solid([System.Drawing.Color]$color) { New-Object System.Drawing.SolidBrush $color }
function RoundedRect([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
    $d = $r * 2
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc((RectF $x $y $d $d), 180, 90)
    $p.AddArc((RectF ($x + $w - $d) $y $d $d), 270, 90)
    $p.AddArc((RectF ($x + $w - $d) ($y + $h - $d) $d $d), 0, 90)
    $p.AddArc((RectF $x ($y + $h - $d) $d $d), 90, 90)
    $p.CloseFigure()
    return $p
}
function Circle([double]$cx, [double]$cy, [double]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddEllipse((RectF ($cx - $r) ($cy - $r) ($r * 2) ($r * 2)))
    return $p
}
# Screen angle: 0 = right, counter-clockwise (as in the addon), y down on the image.
function Polar([double]$cx, [double]$cy, [double]$r, [double]$deg) {
    $a = $deg * [Math]::PI / 180
    return @(($cx + $r * [Math]::Cos($a)), ($cy - $r * [Math]::Sin($a)))
}

function New-Canvas {
    $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (RectF 0 0 $W $H), (Hex '161b26'), (Hex '0a0c11'), ([single]90)
    $g.FillRectangle($bg, 0, 0, $W, $H)
    return @($bmp, $g)
}

# Text drawn as a path: an outline, then the fill. $align: 'left' or 'center' (x is the centre).
function Text($g, [string]$text, [double]$size, [System.Drawing.Color]$color, [double]$x, [double]$y, [string]$align = 'left', [double]$outline = 3, [System.Drawing.FontStyle]$style = $BOLD) {
    $format = New-Object System.Drawing.StringFormat
    if ($align -eq 'center') { $format.Alignment = [System.Drawing.StringAlignment]::Center }
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($text, $FAMILY, [int]$style, [single]$size, (Pt $x $y), $format)
    if ($outline -gt 0) {
        $pen = New-Object System.Drawing.Pen ((Hex '000000' 220)), ([single]$outline)
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($pen, $path)
    }
    $g.FillPath((Solid $color), $path)
    return $path.GetBounds()
}

function Caption($g, [string]$title, [string]$sub) {
    Text $g $title 34 ($C::White) 48 46 | Out-Null
    Text $g $sub 19 (Hex 'b8c2d6') 50 88 'left' 0 ([System.Drawing.FontStyle]::Regular) | Out-Null
    # The icon, top right.
    $logo = Join-Path $PSScriptRoot '..\curseforge\logo.png'
    if (Test-Path $logo) {
        $img = [System.Drawing.Image]::FromFile((Resolve-Path $logo))
        $g.DrawImage($img, (RectF ($W - 112) 24 80 80))
        $img.Dispose()
    }
}

# The battlefield map: the map art in a thin frame, as a rectangle (x, y, w, h).
$NODES = @(@('ST', 0.374, 0.292), @('GM', 0.576, 0.309), @('BS', 0.466, 0.456), @('LM', 0.406, 0.557), @('Farm', 0.560, 0.600))
function Map($g, [double]$x, [double]$y, [double]$w, [double]$h, [switch]$Labels) {
    $img = [System.Drawing.Image]::FromFile($MapImage)
    $g.FillPath((Solid (Hex '000000' 160)), (RoundedRect ($x - 10) ($y - 10) ($w + 20) ($h + 20) 8))
    $g.DrawImage($img, (RectF $x $y $w $h))
    $img.Dispose()
    $frame = New-Object System.Drawing.Pen ((Hex 'c9a25a' 230)), ([single]3)
    $g.DrawPath($frame, (RoundedRect ($x - 2) ($y - 2) ($w + 4) ($h + 4) 4))
    if ($Labels) {
        foreach ($n in $NODES) {
            $px = $x + $n[1] * $w
            $py = $y + $n[2] * $h
            # As BGComs draws them: the code on a dark pill just above the place.
            $probe = New-Object System.Drawing.Drawing2D.GraphicsPath
            $probe.AddString($n[0], $FAMILY, [int]$BOLD, [single]17, (Pt 0 0), [System.Drawing.StringFormat]::GenericDefault)
            $b = $probe.GetBounds()
            $g.FillPath((Solid (Hex '000000' 120)), (RoundedRect ($px - $b.Width / 2 - 6) ($py - 34) ($b.Width + 12) 24 5))
            Text $g $n[0] 17 $GOLD $px ($py - 22) 'center' 3 | Out-Null
        }
    }
}

# --- The wheel's icons, drawn simply (in-game they are Blizzard's ping icons). ---
function Icon($g, [string]$kind, [double]$x, [double]$y, [double]$s, [bool]$selected) {
    $alpha = if ($selected) { 255 } else { 215 }
    switch ($kind) {
        'inc' {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddPolygon([System.Drawing.PointF[]]@((Pt $x ($y - $s * 0.55)), (Pt ($x + $s * 0.6) ($y + $s * 0.45)), (Pt ($x - $s * 0.6) ($y + $s * 0.45))))
            $g.FillPath((Solid (Hex 'f2b33d' $alpha)), $p)
            $g.DrawPath((New-Object System.Drawing.Pen ((Hex '000000' 180)), ([single]2)), $p)
            Text $g '!' ($s * 0.62) (Hex '1a1206') $x ($y + $s * 0.08) 'center' 0 | Out-Null
        }
        'spotted' {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddBezier((Pt ($x - $s * 0.6) $y), (Pt ($x - $s * 0.25) ($y - $s * 0.45)), (Pt ($x + $s * 0.25) ($y - $s * 0.45)), (Pt ($x + $s * 0.6) $y))
            $p.AddBezier((Pt ($x + $s * 0.6) $y), (Pt ($x + $s * 0.25) ($y + $s * 0.45)), (Pt ($x - $s * 0.25) ($y + $s * 0.45)), (Pt ($x - $s * 0.6) $y))
            $g.FillPath((Solid (Hex 'e8eefc' $alpha)), $p)
            $g.FillPath((Solid (Hex 'd63a3a' $alpha)), (Circle $x $y ($s * 0.22)))
            $g.FillPath((Solid (Hex '111111' $alpha)), (Circle $x $y ($s * 0.1)))
        }
        'help' {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddLine((Pt ($x - $s * 0.45) ($y - $s * 0.5)), (Pt ($x + $s * 0.45) ($y - $s * 0.5)))
            $p.AddBezier((Pt ($x + $s * 0.45) ($y - $s * 0.5)), (Pt ($x + $s * 0.45) ($y + $s * 0.15)), (Pt ($x + $s * 0.2) ($y + $s * 0.4)), (Pt $x ($y + $s * 0.58)))
            $p.AddBezier((Pt $x ($y + $s * 0.58)), (Pt ($x - $s * 0.2) ($y + $s * 0.4)), (Pt ($x - $s * 0.45) ($y + $s * 0.15)), (Pt ($x - $s * 0.45) ($y - $s * 0.5)))
            $g.FillPath((Solid (Hex '4f86f0' $alpha)), $p)
            $g.DrawPath((New-Object System.Drawing.Pen ((Hex 'e6edfc' $alpha)), ([single]2.5)), $p)
            $g.FillRectangle((Solid (Hex 'ffffff' $alpha)), (RectF ($x - $s * 0.07) ($y - $s * 0.3) ($s * 0.14) ($s * 0.6)))
            $g.FillRectangle((Solid (Hex 'ffffff' $alpha)), (RectF ($x - $s * 0.25) ($y - $s * 0.07) ($s * 0.5) ($s * 0.14)))
        }
        'omw' {
            foreach ($o in @(-0.22, 0.18)) {
                $pen = New-Object System.Drawing.Pen ((Hex '7fd86a' $alpha)), ([single]($s * 0.16))
                $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                $g.DrawLines($pen, [System.Drawing.PointF[]]@((Pt ($x + ($o - 0.18) * $s) ($y - $s * 0.38)), (Pt ($x + ($o + 0.18) * $s) $y), (Pt ($x + ($o - 0.18) * $s) ($y + $s * 0.38))))
            }
        }
        'clear' {
            $pen = New-Object System.Drawing.Pen ((Hex '5fdc5a' $alpha)), ([single]($s * 0.2))
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawLines($pen, [System.Drawing.PointF[]]@((Pt ($x - $s * 0.42) $y), (Pt ($x - $s * 0.1) ($y + $s * 0.32)), (Pt ($x + $s * 0.45) ($y - $s * 0.38))))
        }
        'efc' {
            $g.FillRectangle((Solid (Hex 'c98a4b' $alpha)), (RectF ($x - $s * 0.36) ($y - $s * 0.55) ($s * 0.08) ($s * 1.1)))
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddPolygon([System.Drawing.PointF[]]@((Pt ($x - $s * 0.28) ($y - $s * 0.5)), (Pt ($x + $s * 0.5) ($y - $s * 0.32)), (Pt ($x + $s * 0.2) ($y - $s * 0.12)), (Pt ($x + $s * 0.5) ($y + $s * 0.08)), (Pt ($x - $s * 0.28) ($y + $s * 0.05))))
            $g.FillPath((Solid (Hex 'd63a3a' $alpha)), $p)
        }
    }
}

# The six calls, as in Data.lua's SECTORS: name, from, to, counted.
$SECTORS = @(
    @('spotted', 'SPOTTED', 0, 60, $true),
    @('inc', 'INC', 60, 120, $true),
    @('help', 'HELP', 120, 180, $false),
    @('omw', 'OMW', 180, 240, $false),
    @('clear', 'CLEAR', 240, 300, $false),
    @('efc', 'EFC', 300, 360, $false)
)
$DEAD, $BAND, $MAXCOUNT = 22, 22, 5
$OUTER = $DEAD + $BAND * $MAXCOUNT
$DISC = $OUTER + 12

# The wheel at (cx, cy): $selected is a sector name or $null, $level the count band (1..6).
function Wheel($g, [double]$cx, [double]$cy, $selected, [int]$level, [string]$loc, [string]$message, [double]$k = 1.0, [switch]$Cursor) {
    $discR = $DISC * $k
    # The dark disc, a soft rim.
    $disc = Circle $cx $cy $discR
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush $disc
    $brush.CenterColor = Hex '0c0f16' 235
    $brush.SurroundColors = @((Hex '1a2131' 225))
    $g.FillPath($brush, $disc)
    $g.DrawPath((New-Object System.Drawing.Pen ((Hex 'ffffff' 55)), ([single]2)), $disc)

    # The selected wedge: a gold glow from the centre out, its rim brighter.
    foreach ($s in $SECTORS) {
        if ($s[0] -ne $selected) { continue }
        $wedge = New-Object System.Drawing.Drawing2D.GraphicsPath
        $wedge.AddPie([single]($cx - $discR), [single]($cy - $discR), [single]($discR * 2), [single]($discR * 2), [single](-$s[3]), [single]($s[3] - $s[2]))
        $glow = New-Object System.Drawing.Drawing2D.PathGradientBrush $wedge
        $glow.CenterPoint = Pt $cx $cy
        $glow.CenterColor = Hex 'ffd100' 10
        $glow.SurroundColors = @((Hex 'ffd100' 75))
        $g.FillPath($glow, $wedge)
        $rim = New-Object System.Drawing.Pen ($GOLD), ([single](4 * $k))
        $g.DrawArc($rim, (RectF ($cx - $discR + 3) ($cy - $discR + 3) (($discR - 3) * 2) (($discR - 3) * 2)), [single](-$s[3] + 1), [single]($s[3] - $s[2] - 2))
        if ($s[4]) {
            # The count rings of this wedge, the current one in gold.
            for ($b = 1; $b -le $MAXCOUNT; $b++) {
                $r = ($DEAD + $BAND * $b) * $k
                $current = ($b -eq [Math]::Min($level, $MAXCOUNT))
                $pen = New-Object System.Drawing.Pen ($(if ($current) { $GOLD } else { Hex 'ffffff' 70 })), ([single]$(if ($current) { 3 } else { 1.5 }))
                $g.DrawArc($pen, (RectF ($cx - $r) ($cy - $r) ($r * 2) ($r * 2)), [single](-$s[3] + 2), [single]($s[3] - $s[2] - 4))
            }
        }
    }

    # Dividers, fading out towards the centre.
    foreach ($s in $SECTORS) {
        $a = Polar $cx $cy (($DEAD - 4) * $k) $s[2]
        $b = Polar $cx $cy ($discR - 4) $s[2]
        $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush (Pt $a[0] $a[1]), (Pt $b[0] $b[1]), (Hex 'ffffff' 0), (Hex 'ffffff' 90)
        $g.DrawLine((New-Object System.Drawing.Pen $lb, ([single]2)), (Pt $a[0] $a[1]), (Pt $b[0] $b[1]))
    }

    # Icons and names.
    foreach ($s in $SECTORS) {
        $mid = ($s[2] + $s[3]) / 2
        $p = Polar $cx $cy (84 * $k) $mid
        $isSel = ($s[0] -eq $selected)
        Icon $g $s[0] $p[0] $p[1] ($(if ($isSel) { 40 } else { 34 }) * $k) $isSel
        $color = if ($isSel) { $GOLD } else { Hex 'ffffff' 220 }
        $q = 45
        if ($mid -gt $q -and $mid -le 180 - $q) { Text $g $s[1] (15 * $k) $color $p[0] ($p[1] - 34 * $k) 'center' 3 | Out-Null }
        elseif ($mid -gt 180 - $q -and $mid -le 180 + $q) { Text $g $s[1] (15 * $k) $color ($p[0] - 62 * $k) $p[1] 'center' 3 | Out-Null }
        elseif ($mid -gt 180 + $q -and $mid -le 360 - $q) { Text $g $s[1] (15 * $k) $color $p[0] ($p[1] + 34 * $k) 'center' 3 | Out-Null }
        else { Text $g $s[1] (15 * $k) $color ($p[0] + 64 * $k) $p[1] 'center' 3 | Out-Null }
    }

    # The blurred centre, the place, the count.
    $shade = Circle $cx $cy (($DEAD + 28) * $k)
    $sb = New-Object System.Drawing.Drawing2D.PathGradientBrush $shade
    $sb.CenterColor = Hex '000000' 210
    $sb.SurroundColors = @((Hex '000000' 0))
    $g.FillPath($sb, $shade)

    # The pointer: a soft gold line from the centre (invisible there) to the cursor.
    if ($selected -and $level -gt 0) {
        $mid = 0
        foreach ($s in $SECTORS) { if ($s[0] -eq $selected) { $mid = ($s[2] + $s[3]) / 2 } }
        $dist = if ($level -le $MAXCOUNT) { $DEAD + $BAND * ($level - 0.5) } else { $OUTER + 16 }
        $end = Polar $cx $cy ($dist * $k) $mid
        $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush (Pt $cx $cy), (Pt $end[0] $end[1]), (Hex 'ffd100' 0), (Hex 'ffd100' 235)
        $pen = New-Object System.Drawing.Pen $lb, ([single](3.5 * $k))
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($pen, (Pt $cx $cy), (Pt $end[0] $end[1]))
        if ($Cursor) {
            # A mouse cursor at the drag's end.
            $cur = New-Object System.Drawing.Drawing2D.GraphicsPath
            $x0, $y0 = $end[0], $end[1]
            $cur.AddPolygon([System.Drawing.PointF[]]@((Pt $x0 $y0), (Pt $x0 ($y0 + 26)), (Pt ($x0 + 6.5) ($y0 + 20)), (Pt ($x0 + 11) ($y0 + 29)), (Pt ($x0 + 15) ($y0 + 27)), (Pt ($x0 + 10.5) ($y0 + 18.5)), (Pt ($x0 + 19) ($y0 + 18.5))))
            $g.FillPath((Solid ($C::White)), $cur)
            $g.DrawPath((New-Object System.Drawing.Pen ($C::Black), ([single]1.6)), $cur)
        }
    }
    Text $g $loc (22 * $k) ($C::White) $cx ($cy - 4 * $k) 'center' 3 | Out-Null
    if ($selected -and ($selected -eq 'inc' -or $selected -eq 'spotted')) {
        $count = if ($level -gt $MAXCOUNT) { "$MAXCOUNT+" } else { "$level" }
        Text $g ("x" + $count) (16 * $k) $GOLD $cx ($cy + 18 * $k) 'center' 3 | Out-Null
    }

    # The message the release sends, on a dark pill under the disc.
    if ($message) {
        $probe = New-Object System.Drawing.Drawing2D.GraphicsPath
        $probe.AddString($message, $FAMILY, [int]$BOLD, [single](19 * $k), (Pt 0 0), [System.Drawing.StringFormat]::GenericDefault)
        $bw = $probe.GetBounds().Width + 28
        $g.FillPath((Solid (Hex '000000' 175)), (RoundedRect ($cx - $bw / 2) ($cy + $discR + 10) $bw (34 * $k) 8))
        Text $g $message (19 * $k) ($C::White) $cx ($cy + $discR + 10 + 17 * $k) 'center' 0 | Out-Null
    }
}

function Save($bmp, $g, [string]$name) {
    $g.Dispose()
    $path = Join-Path $OutDir $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "$path"
}

# --- 1. The map with the place codes. ---
$bmp, $g = New-Canvas
Caption $g '1. Open the battlefield map (Shift-M)' 'BGComs marks the places it knows: Arathi Basin''s bases, Warsong Gulch''s ramps and tunnels, Alterac Valley''s towers...'
Map $g 220 140 840 560 -Labels
Save $bmp $g '1-map.png'

# --- 2. The wheel over Gold Mine: three rings up, INC. ---
$bmp, $g = New-Canvas
Caption $g '2. Middle-click near a base, drag towards a call' 'Drag further for more enemies (1 to 5+). Release to send, or release in the centre to cancel.'
$mx, $my, $mw, $mh = 120, 140, 840, 560
Map $g $mx $my $mw $mh -Labels
$gx = $mx + 0.576 * $mw
$gy = $my + 0.309 * $mh
Wheel $g $gx $gy 'inc' 3 'GM' '3 inc GM' 1.0 -Cursor
Save $bmp $g '2-wheel.png'

# --- 3. Battleground chat. ---
$bmp, $g = New-Canvas
Caption $g '3. Everyone reads it in battleground chat' 'Plain text, sent as you: your teammates need no addon to read it.'
$g.FillPath((Solid (Hex '000000' 150)), (RoundedRect 140 170 1000 470 10))
$instance = Hex 'ff7f00'
$lines = @('3 inc GM', '2 spotted Farm', 'help LM', 'omw BS', 'ST clear', '5+ inc Farm')
$y = 225
foreach ($line in $lines) {
    Text $g ('[Instance] [You]: ' + $line) 30 $instance 180 $y 'left' 2.5 ([System.Drawing.FontStyle]::Regular) | Out-Null
    $y += 68
}
Save $bmp $g '3-chat.png'

# --- 4. The six calls. ---
$bmp, $g = New-Canvas
Caption $g 'Six calls, one gesture' 'INC and SPOTTED take a count; EFC only where there is a flag. The texts can be changed in the options.'
Wheel $g 360 410 'spotted' 2 'ST' '2 spotted ST' 1.4
$notes = @(
    @('Up', 'INC', '"3 inc ST": enemies heading there'),
    @('Up-right', 'SPOTTED', '"2 spotted ST": enemies seen there'),
    @('Up-left', 'HELP', '"help ST"'),
    @('Down-left', 'OMW', '"omw ST": on my way'),
    @('Down', 'CLEAR', '"ST clear": nobody there'),
    @('Down-right', 'EFC', '"EFC ST": enemy flag carrier there')
)
$y = 200
foreach ($n in $notes) {
    Text $g $n[1] 21 $GOLD 690 $y 'left' 2 | Out-Null
    Text $g ($n[0] + ' - ' + $n[2]) 17 (Hex 'dde4f2') 820 $y 'left' 0 ([System.Drawing.FontStyle]::Regular) | Out-Null
    $y += 64
}
Save $bmp $g '4-calls.png'

# Draws BGComs' CurseForge gallery illustrations (1280x720 PNG) into curseforge/gallery/:
#   1-map.png     the battlefield map (Arathi Basin) with the place codes BGComs draws
#   2-wheel.png   a middle-click near Gold Mine, dragged up three rings: "3 inc GM"
#   3-chat.png    the callouts as everyone reads them in battleground chat
#   4-calls.png   the six directions and the count rings
#
#   powershell -File scripts/make-gallery.ps1 -MapImage <Arathi Basin map art, 1002x668 PNG>
#
# These are drawn illustrations, not game captures. The wheel's disc, wedge glow and icons come from
# wheel-art.ps1, the same drawing make-media.ps1 turns into the addon's textures, so they look as in
# the game; the texts use Segoe UI, not the game's font. Replace them with real screenshots when
# there are some. No character names: the sender is "You".
param(
    # Arathi Basin's map art (map 1461), 1002x668, exported from the game files (wow.export: zone 3358).
    [Parameter(Mandatory)][string]$MapImage,
    [string]$OutDir = (Join-Path $PSScriptRoot '..\curseforge\gallery')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wheel-art.ps1')
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }

$W, $H = 1280, 720

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

# The wheel at (cx, cy), as Wheel.lua lays it out: $selected is a call or $null, $level the count
# ring (1..6), $k the scale.
function Wheel($g, [double]$cx, [double]$cy, $selected, [int]$level, [string]$loc, [string]$message, [double]$k = 1.0, [switch]$Cursor) {
    $discR = $DISC * $k
    Draw-Disc $g $cx $cy $k

    # The selected wedge: its gold glow, a gold rim, and for counted calls the count rings, the
    # current one in gold.
    foreach ($s in $SECTORS) {
        if ($s[0] -ne $selected) { continue }
        Draw-Wedge $g $cx $cy $k $s[2] $s[3]
        $rim = New-Object System.Drawing.Pen ($GOLD), ([single](4 * $k))
        $g.DrawArc($rim, (RectF ($cx - $discR + 3 * $k) ($cy - $discR + 3 * $k) (($discR - 3 * $k) * 2) (($discR - 3 * $k) * 2)), [single](-$s[3] + 1), [single]($s[3] - $s[2] - 2))
        if ($s[4]) {
            for ($b = 1; $b -le $MAXCOUNT; $b++) {
                $r = ($DEAD + $BAND * $b) * $k
                $current = ($b -eq [Math]::Min($level, $MAXCOUNT))
                $pen = New-Object System.Drawing.Pen ($(if ($current) { $GOLD } else { Hex 'ffffff' 70 })), ([single]($(if ($current) { 3 } else { 1.5 }) * $k))
                $g.DrawArc($pen, (RectF ($cx - $r) ($cy - $r) ($r * 2) ($r * 2)), [single](-$s[3] + 2), [single]($s[3] - $s[2] - 4))
            }
        }
    }

    # Icons and names: the selected icon 1.15 times larger and opaque, the others at 80%.
    foreach ($s in $SECTORS) {
        $mid = ($s[2] + $s[3]) / 2
        $p = Polar $cx $cy ($ICON_RADIUS * $k) $mid
        $isSel = ($s[0] -eq $selected)
        Draw-CallIcon $g $s[0] $p[0] $p[1] ($ICON_SIZE * $(if ($isSel) { 1.15 } else { 1 }) * $k) $(if ($isSel) { 255 } else { 204 })
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

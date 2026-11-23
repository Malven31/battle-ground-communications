# BGComs' wheel and call icons, drawn with System.Drawing. Shared by:
#   make-media.ps1    the addon's textures in BGComs/media/, which Wheel.lua shows in the game;
#   make-gallery.ps1  the CurseForge illustrations in curseforge/gallery/.
# One drawing for both, so the pictures show what the game draws.
#
#   . (Join-Path $PSScriptRoot 'wheel-art.ps1')
#
# Sizes are UI units times $k: the gallery's scale, or a texture's pixels per UI unit.
# Angles are the addon's: degrees, 0 = right, counter-clockwise. On the image, y goes down.
Add-Type -AssemblyName System.Drawing
$C = [System.Drawing.Color]
$GOLD = $C::FromArgb(255, 255, 209, 0)
$FAMILY = New-Object System.Drawing.FontFamily 'Segoe UI'
$BOLD = [System.Drawing.FontStyle]::Bold

# The geometry of Data.lua (GEOMETRY, SECTORS) and Wheel.lua.
$DEAD, $BAND, $MAXCOUNT = 22, 22, 5
$OUTER = $DEAD + $BAND * $MAXCOUNT   # edge of the count rings (132)
$DISC = $OUTER + 12                  # disc radius (144)
$ICON_RADIUS = 84                    # where each call's icon sits
$ICON_SIZE = 34                      # an icon's size ($s below); its texture spans 1.5 times that
$SECTORS = @(                        # call, name, from, to, counted
    @('spotted', 'SPOTTED', 0, 60, $true),
    @('inc', 'INC', 60, 120, $true),
    @('help', 'HELP', 120, 180, $false),
    @('omw', 'OMW', 180, 240, $false),
    @('clear', 'CLEAR', 240, 300, $false),
    @('efc', 'EFC', 300, 360, $false)
)
# EFC's icon is the enemy's flag.
$FLAG_RED, $FLAG_BLUE = 'd63a3a', '3a7ad6'

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
function Polar([double]$cx, [double]$cy, [double]$r, [double]$deg) {
    $a = $deg * [Math]::PI / 180
    return @(($cx + $r * [Math]::Cos($a)), ($cy - $r * [Math]::Sin($a)))
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

# The dark disc centred on (cx, cy), its soft rim, and the six dividers fading out towards the centre.
function Draw-Disc($g, [double]$cx, [double]$cy, [double]$k) {
    $r = $DISC * $k
    $disc = Circle $cx $cy $r
    $brush = New-Object System.Drawing.Drawing2D.PathGradientBrush $disc
    $brush.CenterColor = Hex '0c0f16' 235
    $brush.SurroundColors = @((Hex '1a2131' 225))
    $g.FillPath($brush, $disc)
    $g.DrawPath((New-Object System.Drawing.Pen ((Hex 'ffffff' 55)), ([single](2 * $k))), $disc)
    foreach ($s in $SECTORS) {
        $a = Polar $cx $cy (($DEAD - 4) * $k) $s[2]
        $b = Polar $cx $cy ($r - 4 * $k) $s[2]
        $lb = New-Object System.Drawing.Drawing2D.LinearGradientBrush (Pt $a[0] $a[1]), (Pt $b[0] $b[1]), (Hex 'ffffff' 0), (Hex 'ffffff' 90)
        $g.DrawLine((New-Object System.Drawing.Pen $lb, ([single](2 * $k))), (Pt $a[0] $a[1]), (Pt $b[0] $b[1]))
    }
}

# The gold glow of the selected wedge, from $from to $to degrees: faint at the centre, brighter at its edges.
function Draw-Wedge($g, [double]$cx, [double]$cy, [double]$k, [double]$from, [double]$to) {
    $r = $DISC * $k
    $wedge = New-Object System.Drawing.Drawing2D.GraphicsPath
    $wedge.AddPie([single]($cx - $r), [single]($cy - $r), [single]($r * 2), [single]($r * 2), [single](-$to), [single]($to - $from))
    $glow = New-Object System.Drawing.Drawing2D.PathGradientBrush $wedge
    $glow.CenterPoint = Pt $cx $cy
    $glow.CenterColor = Hex 'ffd100' 10
    $glow.SurroundColors = @((Hex 'ffd100' 75))
    $g.FillPath($glow, $wedge)
}

# A call's icon centred on (x, y), $s its size (it reaches about 0.6 $s from the centre), $alpha 0-255.
# $flag: EFC's flag colour.
function Draw-CallIcon($g, [string]$kind, [double]$x, [double]$y, [double]$s, [int]$alpha = 255, [string]$flag = $FLAG_RED) {
    switch ($kind) {
        'inc' {
            # A warning triangle with "!".
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddPolygon([System.Drawing.PointF[]]@((Pt $x ($y - $s * 0.55)), (Pt ($x + $s * 0.6) ($y + $s * 0.45)), (Pt ($x - $s * 0.6) ($y + $s * 0.45))))
            $g.FillPath((Solid (Hex 'f2b33d' $alpha)), $p)
            $g.DrawPath((New-Object System.Drawing.Pen ((Hex '000000' ([int]($alpha * 0.7)))), ([single]($s * 0.06))), $p)
            Text $g '!' ($s * 0.62) (Hex '1a1206' $alpha) $x ($y + $s * 0.08) 'center' 0 | Out-Null
        }
        'spotted' {
            # An eye with a red iris.
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddBezier((Pt ($x - $s * 0.6) $y), (Pt ($x - $s * 0.25) ($y - $s * 0.45)), (Pt ($x + $s * 0.25) ($y - $s * 0.45)), (Pt ($x + $s * 0.6) $y))
            $p.AddBezier((Pt ($x + $s * 0.6) $y), (Pt ($x + $s * 0.25) ($y + $s * 0.45)), (Pt ($x - $s * 0.25) ($y + $s * 0.45)), (Pt ($x - $s * 0.6) $y))
            $g.FillPath((Solid (Hex 'e8eefc' $alpha)), $p)
            $g.FillPath((Solid (Hex 'd63a3a' $alpha)), (Circle $x $y ($s * 0.22)))
            $g.FillPath((Solid (Hex '111111' $alpha)), (Circle $x $y ($s * 0.1)))
        }
        'help' {
            # A blue shield with a white cross.
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddLine((Pt ($x - $s * 0.45) ($y - $s * 0.5)), (Pt ($x + $s * 0.45) ($y - $s * 0.5)))
            $p.AddBezier((Pt ($x + $s * 0.45) ($y - $s * 0.5)), (Pt ($x + $s * 0.45) ($y + $s * 0.15)), (Pt ($x + $s * 0.2) ($y + $s * 0.4)), (Pt $x ($y + $s * 0.58)))
            $p.AddBezier((Pt $x ($y + $s * 0.58)), (Pt ($x - $s * 0.2) ($y + $s * 0.4)), (Pt ($x - $s * 0.45) ($y + $s * 0.15)), (Pt ($x - $s * 0.45) ($y - $s * 0.5)))
            $g.FillPath((Solid (Hex '4f86f0' $alpha)), $p)
            $g.DrawPath((New-Object System.Drawing.Pen ((Hex 'e6edfc' $alpha)), ([single]($s * 0.074))), $p)
            $g.FillRectangle((Solid (Hex 'ffffff' $alpha)), (RectF ($x - $s * 0.07) ($y - $s * 0.3) ($s * 0.14) ($s * 0.6)))
            $g.FillRectangle((Solid (Hex 'ffffff' $alpha)), (RectF ($x - $s * 0.25) ($y - $s * 0.07) ($s * 0.5) ($s * 0.14)))
        }
        'omw' {
            # Two green chevrons.
            foreach ($o in @(-0.22, 0.18)) {
                $pen = New-Object System.Drawing.Pen ((Hex '7fd86a' $alpha)), ([single]($s * 0.16))
                $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                $g.DrawLines($pen, [System.Drawing.PointF[]]@((Pt ($x + ($o - 0.18) * $s) ($y - $s * 0.38)), (Pt ($x + ($o + 0.18) * $s) $y), (Pt ($x + ($o - 0.18) * $s) ($y + $s * 0.38))))
            }
        }
        'clear' {
            # A green tick.
            $pen = New-Object System.Drawing.Pen ((Hex '5fdc5a' $alpha)), ([single]($s * 0.2))
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawLines($pen, [System.Drawing.PointF[]]@((Pt ($x - $s * 0.42) $y), (Pt ($x - $s * 0.1) ($y + $s * 0.32)), (Pt ($x + $s * 0.45) ($y - $s * 0.38))))
        }
        'efc' {
            # A flag on its pole.
            $g.FillRectangle((Solid (Hex 'c98a4b' $alpha)), (RectF ($x - $s * 0.36) ($y - $s * 0.55) ($s * 0.08) ($s * 1.1)))
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddPolygon([System.Drawing.PointF[]]@((Pt ($x - $s * 0.28) ($y - $s * 0.5)), (Pt ($x + $s * 0.5) ($y - $s * 0.32)), (Pt ($x + $s * 0.2) ($y - $s * 0.12)), (Pt ($x + $s * 0.5) ($y + $s * 0.08)), (Pt ($x - $s * 0.28) ($y + $s * 0.05))))
            $g.FillPath((Solid (Hex $flag $alpha)), $p)
        }
    }
}

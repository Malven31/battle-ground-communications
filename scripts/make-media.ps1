# Writes BGComs' two helper textures (white, shaped by alpha; tinted in-game with SetVertexColor):
#   media/softline.tga  8x32: a line's cross-section, a soft bell across the height (Line regions
#                       stretch a texture along their length, so the height runs across the line);
#   media/glow.tga      64x64: a round soft glow, opaque in the middle and fading to nothing at the edge.
#
#   powershell -File scripts/make-media.ps1
#
# Uncompressed 32-bit BGRA TGA, bottom-up rows, power-of-two sizes (what WoW reads as an addon texture).
param([string]$Dir = (Join-Path $PSScriptRoot '..\BGComs\media'))
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Force $Dir | Out-Null }

function Write-Tga([string]$path, [int]$w, [int]$h, [scriptblock]$alphaAt) {
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[12] = $w -band 0xFF; $header[13] = $w -shr 8
    $header[14] = $h -band 0xFF; $header[15] = $h -shr 8
    $header[16] = 32
    $header[17] = 8          # 8 alpha bits, bottom-left origin
    $pixels = New-Object byte[] ($w * $h * 4)
    $i = 0
    for ($row = 0; $row -lt $h; $row++) {          # bottom row first
        for ($col = 0; $col -lt $w; $col++) {
            $a = & $alphaAt $col $row
            $a = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($a * 255)))
            $pixels[$i] = 255; $pixels[$i + 1] = 255; $pixels[$i + 2] = 255; $pixels[$i + 3] = [byte]$a
            $i += 4
        }
    }
    $stream = [System.IO.File]::Create($path)
    try { $stream.Write($header, 0, 18); $stream.Write($pixels, 0, $pixels.Length) } finally { $stream.Dispose() }
    Write-Output "$path ($w x $h)"
}

# The line: a raised-cosine bell across the height, full in the middle third, zero at the edges.
Write-Tga (Join-Path $Dir 'softline.tga') 8 32 {
    param($col, $row)
    $t = [Math]::Abs((($row + 0.5) / 32) * 2 - 1)   # 0 in the middle, 1 at the edges
    if ($t -lt 0.3) { return 1.0 }
    $u = ($t - 0.3) / 0.7
    return 0.5 + 0.5 * [Math]::Cos([Math]::PI * $u)
}

# The glow: a smooth falloff from the centre to the rim.
Write-Tga (Join-Path $Dir 'glow.tga') 64 64 {
    param($col, $row)
    $dx = (($col + 0.5) / 64) * 2 - 1
    $dy = (($row + 0.5) / 64) * 2 - 1
    $r = [Math]::Sqrt($dx * $dx + $dy * $dy)
    if ($r -ge 1) { return 0.0 }
    $v = 0.5 + 0.5 * [Math]::Cos([Math]::PI * $r)
    return $v * $v
}

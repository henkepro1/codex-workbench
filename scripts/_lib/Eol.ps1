# UTF-8 LF-safe file writers.
# PowerShell 5.1's Set-Content / Add-Content / Out-File on Windows emit CRLF
# regardless of -Encoding UTF8, which fights the repo's `.gitattributes`
# `* text=auto eol=lf` policy and creates phantom EOL drift on every script
# run. These helpers go through .NET directly so the bytes hit disk as UTF-8
# without BOM, with LF newlines only.

$Script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function ConvertTo-LfText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Content)
    $normalized = $Content -replace "`r`n", "`n"
    if (-not $normalized.EndsWith("`n")) { $normalized += "`n" }
    return $normalized
}

function Write-Utf8Lf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )
    [System.IO.File]::WriteAllText($Path, (ConvertTo-LfText $Content), $Script:Utf8NoBom)
}

function Add-Utf8Lf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )
    [System.IO.File]::AppendAllText($Path, (ConvertTo-LfText $Content), $Script:Utf8NoBom)
}

#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Sdílené funkce pro `tools/` skripty profilu Connectors.Analyst.

.DESCRIPTION
    Dot-source na začátku skriptu:  . "$PSScriptRoot/_common.ps1"

    Konvence tools/ skriptů:
      - cross-platform PowerShell 7+ (shebang, žádné COM / powershell.exe / cmd /c / registry),
      - cesty přes Join-Path / $PSScriptRoot / env vars (žádný hardcoded D:\),
      - multi-user: kořen workspace přes env var PROJECT_ROOT,
      - profil self-contained: žádná reference mimo profil.
#>

Set-StrictMode -Version 3.0

# --------------------------------------------------------------------------
# Cesty
# --------------------------------------------------------------------------

function Get-ProjectRoot {
    <# Kořen workspace z env var PROJECT_ROOT (např. D:/Work/Project). #>
    $root = $env:PROJECT_ROOT
    if ([string]::IsNullOrWhiteSpace($root)) {
        throw "Env var PROJECT_ROOT není nastavena. Nastav ji na kořen workspace, " +
              "např.:  [Environment]::SetEnvironmentVariable('PROJECT_ROOT','D:/Work/Project','User')"
    }
    if (-not (Test-Path -LiteralPath $root)) {
        throw "PROJECT_ROOT='$root' — adresář neexistuje."
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Get-ProfileRoot {
    <# Kořen profilu Connectors.Analyst (rodič tools/, kde leží tento skript). #>
    return (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
}

# --------------------------------------------------------------------------
# Resolve connectoru
# --------------------------------------------------------------------------

function Resolve-Connector {
    <#
    .SYNOPSIS
        Najde adresář connectoru v $PROJECT_ROOT/Connectors/ podle zkratky.
    .DESCRIPTION
        Adresáře mají nested layout `Connector.<X>/`.
        Vstupní zkratka (např. ARES, SK.NespolehlivyPlatce) NENÍ identická
        s názvem adresáře a může vynechat doménové segmenty (`.FinRed.`).
        Match je token-based: vstup se rozdělí na tokeny (`.`/`-`/`_`/mezera)
        a adresář matchne, pokud obsahuje VŠECHNY tokeny (case-insensitive).
        Vrací [System.IO.DirectoryInfo]. Při 0 / >1 shodách vyhodí výjimku.
    #>
    param([Parameter(Mandatory)][string]$Name)

    $connectorsDir = Join-Path (Get-ProjectRoot) 'Connectors'
    if (-not (Test-Path -LiteralPath $connectorsDir)) {
        throw "Adresář connectorů neexistuje: $connectorsDir"
    }

    $all = @(Get-ChildItem -LiteralPath $connectorsDir -Directory |
        Where-Object { $_.Name -like 'Connector.*' })

    $tokens = @($Name -split '[.\-_/\\ ]+' | Where-Object { $_ })
    if ($tokens.Count -eq 0) { throw "Prázdná zkratka connectoru." }

    $found = @($all | Where-Object {
        $dirName = $_.Name
        -not ($tokens | Where-Object { $dirName -notmatch [regex]::Escape($_) })
    })

    if ($found.Count -eq 0) {
        throw "Connector '$Name' nenalezen v $connectorsDir.`n" +
              "Dostupné: $(($all.Name | Sort-Object) -join ', ')"
    }
    if ($found.Count -gt 1) {
        # Preferuj přesnou shodu na segmentu za prefixem Connector.
        $exact = @($found | Where-Object {
            ($_.Name -replace '^Connector\.', '') -ieq $Name
        })
        if ($exact.Count -eq 1) { return $exact[0] }
        throw "Connector '$Name' je nejednoznačný. Kandidáti: $(($found.Name | Sort-Object) -join ', ').`n" +
              "Upřesni název."
    }
    return $found[0]
}

function Resolve-ConnectorSln {
    <# Vrátí .sln v kořeni adresáře connectoru, nebo $null. #>
    param([Parameter(Mandatory)][System.IO.DirectoryInfo]$ConnectorDir)
    return (Get-ChildItem -LiteralPath $ConnectorDir.FullName -Filter '*.sln' -File |
        Select-Object -First 1)
}

function Get-RunnableProjects {
    <#
    .SYNOPSIS
        Spustitelné (.exe) projekty connectoru — kandidáti pro smoke run.
    .DESCRIPTION
        Rekurzivně hledá *.csproj s <OutputType>Exe</OutputType>, vynechává
        bin/obj a testovací projekty (*.Test / *.Tests).
        Vrací pole [System.IO.FileInfo].
    #>
    param([Parameter(Mandatory)][System.IO.DirectoryInfo]$ConnectorDir)

    return @(Get-ChildItem -LiteralPath $ConnectorDir.FullName -Recurse -Filter '*.csproj' -File |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
        Where-Object { $_.BaseName -notmatch '(?i)\.?tests?$' } |
        Where-Object {
            (Get-Content -LiteralPath $_.FullName -Raw) -match '<OutputType>\s*Exe\s*</OutputType>'
        })
}

# --------------------------------------------------------------------------
# Spouštění procesů (cross-platform, s timeoutem)
# --------------------------------------------------------------------------

function Invoke-Capture {
    <#
    .SYNOPSIS
        Spustí proces, zachytí stdout/stderr, vynutí timeout.
    .DESCRIPTION
        stdout/stderr jdou do dočasných souborů (žádný deadlock na plném bufferu).
        Při překročení timeoutu zabije celý strom procesů.
        Vrací [pscustomobject] { ExitCode, Stdout, Stderr, TimedOut, DurationMs }.
    #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSec = 300,
        [hashtable]$EnvVars = @{},
        [string]$WorkingDirectory
    )

    $outFile = New-TemporaryFile
    $errFile = New-TemporaryFile
    $applied = @{}
    foreach ($k in $EnvVars.Keys) {
        $applied[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, [string]$EnvVars[$k])
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $spParams = @{
            FilePath               = $FilePath
            NoNewWindow            = $true
            PassThru               = $true
            RedirectStandardOutput = $outFile.FullName
            RedirectStandardError  = $errFile.FullName
        }
        if ($Arguments.Count -gt 0) { $spParams.ArgumentList = $Arguments }
        if ($WorkingDirectory)      { $spParams.WorkingDirectory = $WorkingDirectory }

        $proc = Start-Process @spParams
        $timedOut = $false
        if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
            $timedOut = $true
            try { $proc.Kill($true) } catch { }
            $proc.WaitForExit()
        }
        $sw.Stop()
        return [pscustomobject]@{
            ExitCode   = $proc.ExitCode
            Stdout     = [string](Get-Content -LiteralPath $outFile.FullName -Raw -ErrorAction SilentlyContinue)
            Stderr     = [string](Get-Content -LiteralPath $errFile.FullName -Raw -ErrorAction SilentlyContinue)
            TimedOut   = $timedOut
            DurationMs = $sw.ElapsedMilliseconds
        }
    }
    finally {
        foreach ($k in $applied.Keys) {
            [Environment]::SetEnvironmentVariable($k, $applied[$k])
        }
        Remove-Item -LiteralPath $outFile.FullName, $errFile.FullName -ErrorAction SilentlyContinue
    }
}

function Invoke-Streamed {
    <#
    .SYNOPSIS
        Spustí proces s výstupem přímo do konzole, vynutí timeout.
    .DESCRIPTION
        Pro wrappery, kde výstup čte volající (AI / člověk) z konzole a skript
        ho neparsuje. Vrací [pscustomobject] { ExitCode, TimedOut, DurationMs }.
    #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSec = 600,
        [hashtable]$EnvVars = @{},
        [string]$WorkingDirectory
    )

    $applied = @{}
    foreach ($k in $EnvVars.Keys) {
        $applied[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, [string]$EnvVars[$k])
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $spParams = @{ FilePath = $FilePath; NoNewWindow = $true; PassThru = $true }
        if ($Arguments.Count -gt 0) { $spParams.ArgumentList = $Arguments }
        if ($WorkingDirectory)      { $spParams.WorkingDirectory = $WorkingDirectory }

        $proc = Start-Process @spParams
        $timedOut = $false
        if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
            $timedOut = $true
            try { $proc.Kill($true) } catch { }
            $proc.WaitForExit()
        }
        $sw.Stop()
        return [pscustomobject]@{
            ExitCode   = $proc.ExitCode
            TimedOut   = $timedOut
            DurationMs = $sw.ElapsedMilliseconds
        }
    }
    finally {
        foreach ($k in $applied.Keys) {
            [Environment]::SetEnvironmentVariable($k, $applied[$k])
        }
    }
}

# --------------------------------------------------------------------------
# Šablony (rendering)
# --------------------------------------------------------------------------

function Expand-TemplateString {
    <#
    .SYNOPSIS
        Nahradí {{Token}} placeholdery v textu hodnotami z hashtable.
    .DESCRIPTION
        Substituce je literální (ne regex) — klíč 'X' nahradí výskyty `{{X}}`.
        Placeholdery, jejichž klíč v $Tokens není, zůstanou beze změny — šablony
        obsahují i ruční fill-in placeholdery, které skript nemá řešit.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [hashtable]$Tokens = @{}
    )
    $result = $Content
    foreach ($key in $Tokens.Keys) {
        $result = $result.Replace("{{$key}}", [string]$Tokens[$key])
    }
    return $result
}

function Copy-TemplateTree {
    <#
    .SYNOPSIS
        Vyrenderuje strom šablon ze SourceDir do DestDir.
    .DESCRIPTION
        Rekurzivně projde SourceDir. Soubory `*.tmpl` vyrenderuje (substituce
        {{Token}} z $Tokens přes Expand-TemplateString) a uloží do DestDir bez
        přípony `.tmpl`, se zachováním relativní cesty. Ostatní soubory zkopíruje
        1:1. Existující cílové soubory NEpřepisuje (Action = 'Skipped').
        -Preview vrátí plán bez jakéhokoli zápisu.
        Vrací pole [pscustomobject] { RelPath; FullPath; Action } (Created|Skipped).
    #>
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestDir,
        [hashtable]$Tokens = @{},
        [switch]$Preview
    )
    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        throw "Zdroj šablon neexistuje: $SourceDir"
    }
    $srcRoot = (Resolve-Path -LiteralPath $SourceDir).Path

    $report = foreach ($f in (Get-ChildItem -LiteralPath $srcRoot -Recurse -File)) {
        $rel      = [System.IO.Path]::GetRelativePath($srcRoot, $f.FullName)
        $isTmpl   = $f.Extension -ieq '.tmpl'
        $relOut   = $isTmpl ? $rel.Substring(0, $rel.Length - $f.Extension.Length) : $rel
        $destPath = Join-Path $DestDir $relOut
        $action   = (Test-Path -LiteralPath $destPath) ? 'Skipped' : 'Created'

        if ($action -eq 'Created' -and -not $Preview) {
            $destParent = Split-Path -Parent $destPath
            if ($destParent -and -not (Test-Path -LiteralPath $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }
            if ($isTmpl) {
                $content  = [string](Get-Content -LiteralPath $f.FullName -Raw)
                $rendered = Expand-TemplateString -Content $content -Tokens $Tokens
                Set-Content -LiteralPath $destPath -Value $rendered -Encoding utf8 -NoNewline
            }
            else {
                Copy-Item -LiteralPath $f.FullName -Destination $destPath
            }
        }
        [pscustomobject]@{ RelPath = $relOut; FullPath = $destPath; Action = $action }
    }
    return @($report)
}

# --------------------------------------------------------------------------
# Docs adresář connectoru
# --------------------------------------------------------------------------

function Resolve-ConnectorDocsDir {
    <#
    .SYNOPSIS
        Najde (nebo navrhne) docs/ adresář connectoru.
    .DESCRIPTION
        Reálné connectory drží dokumentaci v src/<name>/docs (u RPV varianta
        `Docs`, u Ares docs/ v rootu). Vrací první existující docs adresář.
        Pokud žádný není a -MustExist není zadán, navrhne preferovanou cestu
        pro vytvoření: src/<name>/docs, jinak <name>/docs.
    #>
    param(
        [Parameter(Mandatory)][System.IO.DirectoryInfo]$ConnectorDir,
        [switch]$MustExist
    )
    $name = $ConnectorDir.Name
    $candidates = @(
        (Join-Path $ConnectorDir.FullName "src/$name/docs"),
        (Join-Path $ConnectorDir.FullName "src/$name/Docs"),
        (Join-Path $ConnectorDir.FullName 'docs'),
        (Join-Path $ConnectorDir.FullName 'Docs')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Container) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    if ($MustExist) {
        throw "Connector '$name' nemá docs/ adresář.`nHledáno: $($candidates -join ', ')."
    }
    $srcSub = Join-Path $ConnectorDir.FullName "src/$name"
    if (Test-Path -LiteralPath $srcSub -PathType Container) {
        return (Join-Path $srcSub 'docs')
    }
    return (Join-Path $ConnectorDir.FullName 'docs')
}

# --------------------------------------------------------------------------
# state/snapshots-log.md
# --------------------------------------------------------------------------

function Add-SnapshotLogEntry {
    <#
    .SYNOPSIS
        Vloží záznam do state/snapshots-log.md (append-only log).
    .DESCRIPTION
        Záznam se vkládá před marker "<!-- Další záznamy připisuj sem -->",
        aby marker zůstal poslední. Pokud marker chybí, připíše na konec.
    #>
    param(
        [Parameter(Mandatory)][string]$EntryMarkdown
    )

    $logPath = Join-Path (Get-ProfileRoot) 'state/snapshots-log.md'
    if (-not (Test-Path -LiteralPath $logPath)) {
        throw "snapshots-log.md nenalezen: $logPath"
    }

    $content = Get-Content -LiteralPath $logPath -Raw
    $marker  = '<!-- Další záznamy připisuj sem -->'
    $block   = "$($EntryMarkdown.TrimEnd())`n`n---`n`n"

    if ($content.Contains($marker)) {
        $content = $content.Replace($marker, "$block$marker")
    }
    else {
        $content = $content.TrimEnd() + "`n`n$block"
    }
    Set-Content -LiteralPath $logPath -Value $content -Encoding utf8 -NoNewline
    return $logPath
}

<#
.SYNOPSIS
  Sample AppCentral host in PowerShell.
.DESCRIPTION
  Loads the AppCentral library (root AppCentral.ps1) and exercises a plugin.
.EXAMPLE
  .\main.ps1 C:\Beispiele\AppCentral\Output\ExampleDelphiDLL.dll
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$DllPath,
    [string]$SecondDllPath = ""
)

# Dot-source the library (located at the AppCentral root, two levels up).
. (Join-Path $PSScriptRoot "..\..\AppCentral.ps1")

Write-Host "=== AppCentral PowerShell host ===" -ForegroundColor Cyan
Write-Host ""

$ac = New-Object AppCentralPS.AppCentral

Write-Host "Loading $DllPath..."
if (-not $ac.LoadPlugin($DllPath)) {
    Write-Host "ERROR: Could not load plugin" -ForegroundColor Red
    exit 1
}
Write-Host "Loaded."

if ($SecondDllPath -ne "") {
    Write-Host "Loading $SecondDllPath..."
    if ($ac.LoadPlugin($SecondDllPath)) {
        Write-Host "Second plugin loaded."
    }
}

Write-Host ""
Write-Host "--- Plugin list ---"
for ($i = 0; $i -lt $ac.PluginCount; $i++) {
    Write-Host ("  [{0}] {1}" -f $i, $ac.PluginFilename($i))
}
Write-Host ""

$hello = $ac.ExampleSayHello("World")
if ($hello -ne $null) {
    Write-Host ("IExample.SayHello: " + $hello)
    Write-Host ("IExample.Add(3, 4): " + $ac.ExampleAdd(3, 4))
} else {
    Write-Host "ERROR: IExample not found!" -ForegroundColor Red
}

Write-Host ""
$all = $ac.AllExamplesSayHello("Plugin")
Write-Host "Plugins offering IExample: $($all.Length)"
for ($i = 0; $i -lt $all.Length; $i++) {
    Write-Host ("  Plugin {0}: {1}" -f $i, $all[$i])
}

Write-Host ""
Write-Host "Shutdown..."
$ac.Shutdown()
Write-Host "Done."

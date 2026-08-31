# Install a built watch face onto a Forerunner 970 over USB.
#
#   powershell -ExecutionPolicy Bypass -File tools\install.ps1 -App Recon
#   powershell -ExecutionPolicy Bypass -File tools\install.ps1 -App Clay
#
# The watch mounts as an MTP DEVICE, not a drive letter, so it has no path
# a normal copy can reach. Everything here goes through the Windows shell
# COM object. Walking the namespace by name works; handing it a path
# string does not.
#
# Run it from a terminal you can leave alone -- if CopyHere ever hits a
# replace dialog it blocks until the dialog is answered.
#
# What success looks like: on disconnect the watch INSTALLS the .prg and
# deletes the file, so an empty Apps/ folder next time is success, not a
# failed copy.

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("Clay", "Recon")]
  [string]$App,

  [string]$Device = "Forerunner 970"
)

$ErrorActionPreference = "Stop"
$shell = New-Object -ComObject Shell.Application

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path (Join-Path $root $App.ToLower()) "bin"

function Get-Node($parts) {
  # Retried: the device takes a moment to publish its namespace after
  # being plugged in, and the first walk routinely comes back empty.
  for ($try = 0; $try -lt 5; $try++) {
    $n = $shell.NameSpace(17); $ok = $true
    foreach ($part in $parts) {
      $found = $null
      foreach ($i in $n.Items()) { if ($i.Name -eq $part) { $found = $i; break } }
      if (-not $found) { $ok = $false; break }
      $n = $found.GetFolder
    }
    if ($ok -and $n) { return $n }
    Start-Sleep -Milliseconds 800
  }
  return $null
}

$apps = Get-Node @($Device, "Internal Storage", "GARMIN", "Apps")
$sets = Get-Node @($Device, "Internal Storage", "GARMIN", "Apps", "SETTINGS")
if (-not $apps -or -not $sets) {
  Write-Output "WATCH NOT MOUNTED -- plug it in and unlock it, then retry."
  exit 1
}

# MTP does NOT reliably overwrite. CopyHere can leave an existing file
# untouched and still report success, so delete first. InvokeVerb("delete")
# silently no-ops on a .prg even though it works on .SET files, hence the
# explicit check afterwards rather than trusting it.
foreach ($i in @($apps.Items())) {
  if ($i.Name -eq "$App.prg") {
    Write-Output "stale $App.prg present, deleting ..."
    $i.InvokeVerb("delete"); Start-Sleep -Seconds 3
  }
}

# A stored setting SURVIVES replacing the .prg, and a sideloaded build has
# no settings UI on the watch to correct a bad stored value. If a new build
# behaves as though it ignored a properties.xml change, this is why.
foreach ($i in @($sets.Items())) {
  if ($i.Name -eq "$App.SET") {
    Write-Output "clearing $App.SET ..."
    $i.InvokeVerb("delete"); Start-Sleep -Seconds 2
  }
}

$stale = $null
foreach ($i in @($apps.Items())) { if ($i.Name -eq "$App.prg") { $stale = $i } }
if ($stale) {
  Write-Output "COULD NOT REMOVE the existing $App.prg."
  Write-Output "Unplug the watch to let it consume that file, plug back in, rerun."
  exit 1
}

$folder = $shell.NameSpace($src)
if (-not $folder) { Write-Output "NO BUILD DIRECTORY: $src"; exit 1 }
$prg = $null
foreach ($i in $folder.Items()) { if ($i.Name -eq "$App.prg") { $prg = $i } }
if (-not $prg) {
  Write-Output "NOT BUILT: $src\$App.prg"
  Write-Output "Build it, or drop the .prg from the latest release there."
  exit 1
}

Write-Output ("copying $App.prg (" + $prg.ExtendedProperty("Size") + " bytes) ...")
$apps.CopyHere($prg, 16)
Start-Sleep -Seconds 10

# Verify size and timestamp rather than trusting the copy dialog. An
# Explorer drag to MTP once left Apps/ with no .prg in it at all.
Write-Output ""
Write-Output "=== Apps ==="
foreach ($i in $apps.Items()) {
  if ($i.IsFolder) { continue }
  Write-Output ("  {0,-22} {1,-12} {2}" -f $i.Name, $apps.GetDetailsOf($i, 2), $apps.GetDetailsOf($i, 3))
}
Write-Output ""
Write-Output "Now UNPLUG the watch. It installs the .prg on disconnect and"
Write-Output "deletes the file, so an empty Apps/ next time means it worked."
Write-Output "Then long-press UP on the watch face and pick $App."

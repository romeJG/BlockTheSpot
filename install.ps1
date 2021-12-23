# Ignore errors from `Stop-Process`
$PSDefaultParameterValues['Stop-Process:ErrorAction'] = [System.Management.Automation.ActionPreference]::SilentlyContinue

Write-Host -Object @'
*****************
@mrpond message:
#Thailand #ThaiProtest #ThailandProtest #freeYOUTH
Please retweet these hashtag, help me stop dictator government!
*****************
'@

Write-Host -Object @'
*****************
Author: @Nuzair46
*****************
'@

$SpotifyDirectory = Join-Path -Path $env:APPDATA -ChildPath 'Spotify'
$SpotifyExecutable = Join-Path -Path $SpotifyDirectory -ChildPath 'Spotify.exe'
$SpotifyApps = Join-Path -Path $SpotifyDirectory -ChildPath 'Apps'

Write-Host -Object "Stopping Spotify...`n"
Stop-Process -Name Spotify
Stop-Process -Name SpotifyWebHelper

if ($PSVersionTable.PSVersion.Major -ge 7)
{
  Import-Module Appx -UseWindowsPowerShell
}

if (Get-AppxPackage -Name SpotifyAB.SpotifyMusic)
{
  Write-Host "The Microsoft Store version of Spotify has been detected which is not supported.`n"

  $ch = Read-Host -Prompt 'Uninstall Spotify Windows Store edition (Y/N)'
  if ($ch -eq 'y')
  {
    Write-Host "Uninstalling Spotify.`n"
    Get-AppxPackage -Name SpotifyAB.SpotifyMusic | Remove-AppxPackage
  }
  else
  {
    Read-Host "Exiting...`nPress any key to exit..."
    exit
  }
}

Push-Location -LiteralPath $env:TEMP
try
{
  # Unique directory name based on time
  New-Item -Type Directory -Name "BlockTheSpot-$(Get-Date -UFormat '%Y-%m-%d_%H-%M-%S')" |
  Convert-Path |
  Set-Location
}
catch
{
  Write-Output $_
  Read-Host 'Press any key to exit...'
  exit
}

Write-Host "Downloading latest patch (chrome_elf.zip)...`n"
$webClient = New-Object -TypeName ([System.Net.WebClient])
$elfPath = Join-Path -Path $PWD -ChildPath 'chrome_elf.zip'
try
{
  $webClient.DownloadFile(
    # Remote file URL
    'https://github.com/mrpond/BlockTheSpot/releases/latest/download/chrome_elf.zip',
    # Local file path
    "$elfPath"
  )
}
catch
{
  Write-Output $_
  Start-Sleep
}

Expand-Archive -Force -LiteralPath "$elfPath" -DestinationPath $PWD
Remove-Item -LiteralPath "$elfPath" -Force

$spotifyInstalled = Test-Path -LiteralPath $SpotifyExecutable
$update = $false
if ($spotifyInstalled)
{
  $ch = Read-Host -Prompt 'Optional - Update Spotify to the latest version. (Might already be updated). (Y/N)'
  if ($ch -eq 'y')
  {
    $update = $true
  }
  else
  {
    Write-Host 'Won''t try to update Spotify.'
  }
}
else
{
  Write-Host 'Spotify installation was not detected.'
}
if (-not $spotifyInstalled -or $update)
{
  Write-Host 'Downloading Latest Spotify full setup, please wait...'
  $spotifySetupFilePath = Join-Path -Path $PWD -ChildPath 'SpotifyFullSetup.exe'
  try
  {
    $webClient.DownloadFile(
      # Remote file URL
      'https://download.scdn.co/SpotifyFullSetup.exe',
      # Local file path
      "$spotifySetupFilePath"
    )
  }
  catch
  {
    Write-Output $_
    Read-Host 'Press any key to exit...'
    exit
  }
  New-Item -Path $SpotifyDirectory -ItemType:Directory -Force | Write-Verbose
  Write-Host 'Running installation...'
  Start-Process -FilePath "$spotifySetupFilePath"
  while ($null -eq (Get-Process -Name Spotify -ErrorAction SilentlyContinue))
  {
    #waiting until installation complete
  }
  Write-Host 'Stopping Spotify...Again'

  Stop-Process -Name Spotify
  Stop-Process -Name SpotifyWebHelper
  Stop-Process -Name SpotifyFullSetup
}
$elfDllBackFilePath = Join-Path -Path $SpotifyDirectory -ChildPath 'chrome_elf_bak.dll'
$elfBackFilePath = Join-Path -Path $SpotifyDirectory -ChildPath 'chrome_elf.dll'
if ((Test-Path $elfDllBackFilePath) -eq $false)
{
  Move-Item -LiteralPath "$elfBackFilePath" -Destination "$elfDllBackFilePath" | Write-Verbose
}

Write-Host 'Patching Spotify...'
$patchFiles = (Join-Path -Path $PWD -ChildPath 'chrome_elf.dll'), (Join-Path -Path $PWD -ChildPath 'config.ini')

Copy-Item -LiteralPath $patchFiles -Destination "$SpotifyDirectory"

$ch = Read-Host -Prompt 'Optional - Remove ad placeholder and upgrade button. (Y/N)'
if ($ch -eq 'y')
{
  $xpuiBundlePath = Join-Path -Path $SpotifyApps -ChildPath 'xpui.spa'
  $xpuiUnpackedPath = Join-Path -Path (Join-Path -Path $SpotifyApps -ChildPath 'xpui') -ChildPath 'xpui.js'
  $fromZip = $false

  # Try to read xpui.js from xpui.spa for normal Spotify installations, or
  # directly from Apps/xpui/xpui.js in case Spicetify is installed.
  if (Test-Path $xpuiBundlePath)
  {
    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    Copy-Item -Path $xpuiBundlePath -Destination "$xpuiBundlePath.bak"

    $zip = [System.IO.Compression.ZipFile]::Open($xpuiBundlePath, 'update')
    $entry = $zip.GetEntry('xpui.js')

    # Extract xpui.js from zip to memory
    $reader = New-Object System.IO.StreamReader($entry.Open())
    $xpuiContents = $reader.ReadToEnd()
    $reader.Close()

    $fromZip = $true
  }
  elseif (Test-Path $xpuiUnpackedPath)
  {
    Copy-Item -LiteralPath $xpuiUnpackedPath -Destination "$xpuiUnpackedPath.bak"
    $xpuiContents = Get-Content -LiteralPath $xpuiUnpackedPath -Raw

    Write-Host -Object 'Spicetify detected - You may need to reinstall BTS after running "spicetify apply".';
  }
  else
  {
    Write-Host -Object 'Could not find xpui.js, please open an issue on the BlockTheSpot repository.'
  }

  if ($xpuiContents)
  {
    # Replace ".ads.leaderboard.isEnabled" + separator - '}' or ')'
    # With ".ads.leaderboard.isEnabled&&false" + separator
    $xpuiContents = $xpuiContents -replace '(\.ads\.leaderboard\.isEnabled)(}|\))', '$1&&false$2'

    # Delete ".createElement(XX,{onClick:X,className:XX.X.UpgradeButton}),X()"
    $xpuiContents = $xpuiContents -replace '\.createElement\([^.,{]+,{onClick:[^.,]+,className:[^.]+\.[^.]+\.UpgradeButton}\),[^.(]+\(\)', ''

    if ($fromZip)
    {
      # Rewrite it to the zip
      $writer = New-Object System.IO.StreamWriter($entry.Open())
      $writer.BaseStream.SetLength(0)
      $writer.Write($xpuiContents)
      $writer.Close()

      $zip.Dispose()
    }
    else
    {
      Set-Content -LiteralPath $xpuiUnpackedPath -Value $xpuiContents
    }
  }
}
else
{
  Write-Host -Object "Won't remove ad placeholder and upgrade button.`n"
}

$tempDirectory = $PWD
Pop-Location

Remove-Item -LiteralPath $tempDirectory -Recurse

Write-Host -Object 'Patching Complete, starting Spotify...'
Start-Process -WorkingDirectory $SpotifyDirectory -FilePath $SpotifyExecutable
Write-Host -Object 'Done.'

Write-Host -Object @'
*****************
@mrpond message:
#Thailand #ThaiProtest #ThailandProtest #freeYOUTH
Please retweet these hashtag, help me stop dictator government!
*****************
'@

exit

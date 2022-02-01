<#
.SYNOPSIS
    Install Winget packages

.DESCRIPTION
    Installs Winget and desired packages on Windows

.LINK
    https://github.com/PowerProfile/psprofile-common
#>

$HasPackageManager = $false

# winget on Windows 11 is so slooooow ... >:-(
if ([System.Environment]::OSVersion.Version.Build -ge 22000) {
  $response = Read-Host -Prompt '       This might take a while: Check for missing software now? [y/N]> '
  if ($response -ine 'y') {
    break
  }
}

if (Get-Command winget -CommandType Application -ErrorAction Ignore) {
  $HasPackageManager = $true
} else {
  Start-Job -Name WingetInstall -ScriptBlock { Add-AppxPackage -Path https://aka.ms/getwinget -ErrorAction Ignore }
  Wait-Job -Name WingetInstall

  if (Get-Command winget -CommandType Application -ErrorAction Ignore) {
    $HasPackageManager = $true
  }
}

if ($HasPackageManager) {
  $ConfigDir = Join-Path $(Split-Path $MyInvocation.MyCommand.Path) $(Join-Path 'Config' 'Winget')

  if (Test-Path -PathType Container $ConfigDir -ErrorAction Ignore) {
    Push-Location $ConfigDir

    Get-ChildItem *.winget.json -Exclude global-* -Recurse -File -FollowSymlink | ForEach-Object {
      $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
      foreach ($Source in $json.Sources) {
        foreach ($Package in $Source.Packages) {
          $listApp = winget list --exact --source $source.SourceDetails.Name -q $Package.PackageIdentifier
          if (-Not [String]::Join("", $listApp).Contains($Package.PackageIdentifier)) {
            Write-Host ('      * Installing ' + $Package.PackageIdentifier + ' ...')
            $null = winget install --exact --silent $Package.PackageIdentifier --source $source.SourceDetails.Name --accept-source-agreements --accept-package-agreements
          }
        }
      }
    }

    if ($env:IsElevated) {
      Get-ChildItem global-*.winget.json -Recurse -File -FollowSymlink | ForEach-Object {
        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
        foreach ($Source in $json.Sources) {
          foreach ($Package in $Source.Packages) {
            $listApp = winget list --exact --source $source.SourceDetails.Name -q $Package.PackageIdentifier
            if (-Not [String]::Join("", $listApp).Contains($Package.PackageIdentifier)) {
              Write-Host ('      * Installing ' + $Package.PackageIdentifier + ' ...')
              $null = winget install --exact --silent $Package.PackageIdentifier --source $source.SourceDetails.Name --accept-source-agreements --accept-package-agreements
            }
          }
        }
      }
    }

    Pop-Location
  }
}

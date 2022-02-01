<#
.SYNOPSIS
    Install Scoop packages

.DESCRIPTION
    Installs Scoop and desired packages on Windows

.LINK
    https://github.com/PowerProfile/psprofile-common
#>

$HasScoop = $false

if (Get-Command scoop -CommandType Application -ErrorAction Ignore) {
  $HasScoop = $true
} else {
  $null = Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh/')

  if (Get-Command scoop -CommandType Application -ErrorAction Ignore) {
    $HasScoop = $true
  }
}

if ($HasScoop) {
  $ConfigDir = Join-Path $(Split-Path $MyInvocation.MyCommand.Path) $(Join-Path 'Config' 'Scoop')

  if (Test-Path -PathType Container $ConfigDir -ErrorAction Ignore) {
    Push-Location $ConfigDir

    $buckets = scoop bucket list
    $apps = $(scoop export) | Select-String '^(\S+) *(?:\(v:(\w+)\))? *(?:\[(\S+)\])?$' | ForEach-Object { $_.matches.groups[1].value }

    Get-ChildItem *.scoop.json -Exclude global-* -Recurse -File | ForEach-Object {
      $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
      foreach ($Bucket in $json.Buckets) {
        if (-Not $buckets.Contains($Bucket.BucketDetails.Name)) {
          scoop bucket add $Bucket.BucketDetails.Name
        }

        foreach ($App in $Bucket.Apps) {
          if ($apps -and -not $apps.Contains($App.Name)) {
            scoop install $App.Name
          }
        }
      }
    }

    if ($env:IsElevated) {
      Get-ChildItem global-*.scoop.json -Recurse -File | ForEach-Object {
        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
        foreach ($Bucket in $json.Buckets) {
          if (-Not $buckets.Contains($Bucket.BucketDetails.Name)) {
            scoop bucket add $Bucket.BucketDetails.Name
          }

          foreach ($App in $Bucket.Apps) {
            if ($apps -and -not $apps.Contains($App.Name)) {
              scoop install $App.Name --global
            }
          }
        }
      }
    }

    Pop-Location
  }
}

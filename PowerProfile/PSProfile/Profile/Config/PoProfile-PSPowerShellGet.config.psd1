@{
    PowerShellGetV2toV3 = @{
        MinimumVersion = '3.0.12-beta'
        MaximumVersion = '3.0.12-beta'
        AllowPrerelease = $true
    }
    PowerShellGet = @{
        Version = '3.0.12-beta'
        Prerelease = $true
    }
    PSResourceRepository = @(
        @{
            Name = 'PSGallery'
            Trusted = $true
            Priority = 50
        }
        @{
            Name = 'PSTestGallery'
            URL = 'https://www.poshtestgallery.com/api/v2'
            Trusted = $true
            Priority = 50
        }
    )
}

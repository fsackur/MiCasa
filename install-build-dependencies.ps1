$Dependencies = (
    @{
        Name = 'Pester'
        MinimumVersion = '5.3.1'
    },
    @{
        Name = 'PowerShellGet'
        RequiredVersion = '3.0.16-beta16'
        MinimumVersion = '3.0.16'
    },
    @{
        Name = 'InvokeBuild'
        MinimumVersion = '5.9.12'
    }
)

# https://github.com/PowerShell/PowerShellGet/issues/835
$BadVersion = Get-Module -ListAvailable -FullyQualifiedName @{ModuleName = 'PowerShellGet'; RequiredVersion = '3.0.17'}
if ($BadVersion)
{
    $BadVersion.ModuleBase | Remove-Item -Recurse -Force
}

$Dependencies | % {
    if (-not (Get-Module $_.Name -ListAvailable -ErrorAction Ignore | ? Version -ge $_.MinimumVersion))
    {
        $Params = @{
            Force              = $true
            AllowClobber       = $true
            Repository         = 'PSGallery'
            SkipPublisherCheck = $true
        }

        if ($_.Name -eq 'PowerShellGet')
        {
            $Params.AllowPrerelease = $true
            $_.Remove('MinimumVersion')
        }

        Write-Verbose -Verbose "Installing $($_.Name)..."
        Install-Module @Params @_
    }
}

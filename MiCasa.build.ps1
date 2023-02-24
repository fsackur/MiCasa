#requires -Modules @{ModuleName = 'InvokeBuild'; ModuleVersion = '5.9.12'}, @{ModuleName = 'PowerShellGet'; ModuleVersion = '3.0.16'}

param
(
    [string]$Tag,

    [string]$PSGalleryApiKey
)

# Synopsis: Update manifest version
task UpdateVersion {
    $ManifestPath = "MiCasa.psd1"
    $ManifestContent = Get-Content $ManifestPath -Raw
    $Manifest = Invoke-Expression "DATA {$ManifestContent}"
    [version]$CurrentVersion = $Manifest.ModuleVersion

    $NewVersion = $Tag -replace '^\D*' -replace '\D*$' -as [Version]
    $TagIsVersion = [bool]$NewVersion
    if (-not $TagIsVersion)
    {
        $Major, $Minor, $Build = $CurrentVersion.Major, $CurrentVersion.Minor, $CurrentVersion.Build
        $null = switch ($Tag)
        {
            'Major' {$Major++; $Minor = $Build = 0}
            'Minor' {$Minor++; $Build = 0}
            'Build' {$Build++}
            default {throw "Tag '$Tag' should be a version, or one of 'Major', 'Minor', 'Build'."}
        }
        $NewVersion = [version]::new($Major, $Minor, $Build)
    }

    if ($NewVersion -eq $CurrentVersion)
    {
        Write-Verbose "Already at version $Version."
        return
    }
    elseif ($NewVersion -lt $CurrentVersion)
    {
        throw "Can't go backwards: $NewVersion =\=> $($Manifest.ModuleVersion)"
    }

    $ModuleVersionPattern = "(?<=\n\s*ModuleVersion\s*=\s*(['`"]))(\d+\.)+\d+"

    $ManifestContent = $ManifestContent -replace $ModuleVersionPattern, $NewVersion
    $ManifestContent | Out-File $ManifestPath -Encoding utf8
    Write-Build Green "Updated version: $NewVersion"
}

# Synopsis: Run PSSA, excluding Tests folder and *.build.ps1
task PSSA {
    $Files = Get-ChildItem -File -Recurse -Filter *.ps*1 | Where-Object FullName -notmatch '\bTests\b|\.build\.ps1$|install-build-dependencies\.ps1'
    $Files | ForEach-Object {
        Invoke-ScriptAnalyzer -Path $_.FullName -Recurse -Settings .\.vscode\PSScriptAnalyzerSettings.psd1
    }
}

# Synopsis: Clean build folder
task Clean {
    remove Build
}

# Synopsis: Build module at manifest version
task Build Clean, {
    $ManifestPath = "MiCasa.psd1"
    $ManifestContent = Get-Content $ManifestPath -Raw
    $Manifest = Invoke-Expression "DATA {$ManifestContent}"

    $Version = $Manifest.ModuleVersion
    $BuildFolder = New-Item "Build/MiCasa/$Version" -ItemType Directory -Force
    $BuiltManifestPath = Join-Path $BuildFolder $ManifestPath
    $BuiltRootModulePath = Join-Path $BuildFolder $Manifest.RootModule

    Copy-Item $ManifestPath $BuildFolder
    Copy-Item "README.md" $BuildFolder
    Copy-Item "LICENSE" $BuildFolder

    'Private', 'Public' | ForEach-Object {
        "",
        "#region $_",
        ($_ | Get-ChildItem | Get-Content),
        "#endregion $_",
        ""
    } |
        Write-Output |
        Out-File $BuiltRootModulePath -Encoding utf8NoBOM
}

# Synopsis: Import latest version of module from build folder
task Import Build, {
    Import-Module "$BuildRoot/Build/MiCasa" -Force -Global -ErrorAction Stop
}

task Test Import, {
    Invoke-Pester
}

task Tag {
    $ManifestPath = "MiCasa.psd1"
    if (-not $Tag)
    {
        $Version = (Test-ModuleManifest $ManifestPath -ErrorAction Stop).Version
        $Tag = "v$Version"
    }

    if ($Tag -in (git tag))
    {
        Write-Build Blue "Tag $Tag already present"
        return
    }

    $Modified = (git status -s) -replace '^...'
    if ($ManifestPath -in $Modified)
    {
        $Result = git add $ManifestPath *>&1 | Out-String | % Trim
        if (-not $?)
        {
            throw $Result
        }

        $Result = git commit -m $Tag *>&1 | Out-String | % Trim
        if (-not $?)
        {
            throw $Result
        }
    }

    $Result = git tag $Tag *>&1 | Out-String | % Trim
    if (-not $?)
    {
        throw $Result
    }
    Write-Build Green "Tagged $Tag"

    $Result = git push --tags *>&1 | Out-String | % Trim
    if (-not $?)
    {
        throw $Result
    }

    $Result = git switch -C main *>&1 | Out-String | % Trim
    if (-not $?)
    {
        throw $Result
    }

    $Result = git push origin HEAD:main *>&1 | Out-String | % Trim
    if (-not $?)
    {
        throw $Result
    }
}

task PrepPublishableContent Build, {
    $UnversionedBase = "Build/MiCasa"
    $VersionedBase = Get-Module $UnversionedBase -ListAvailable | ForEach-Object ModuleBase
    Get-ChildItem $VersionedBase | Move-Item -Destination $UnversionedBase
    remove $VersionedBase
}

Task BuildNupkg PrepPublishableContent, {
    $UnversionedBase = "Build/MiCasa"
    if (-not (Get-PSResourceRepository PipelineArtifacts -ErrorAction Ignore))
    {
        Register-PSResourceRepository PipelineArtifacts -Uri ./Build -Trusted
    }
    Publish-PSResource -Verbose -Path $UnversionedBase -Repository PipelineArtifacts
}

task Publish PrepPublishableContent, {
    $UnversionedBase = "Build/MiCasa"
    Publish-PSResource -Verbose -Path $UnversionedBase -Repository PSGallery -ApiKey $PSGalleryApiKey
}

task . PSSA, Test

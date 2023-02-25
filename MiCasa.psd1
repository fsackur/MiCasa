@{
    Description          = 'Use chezmoi to manage your dotfiles across multiple diverse machines, securely.'
    ModuleVersion        = '0.0.1'
    HelpInfoURI          = 'https://pages.github.com/fsackur/MiCasa'

    CompatiblePSEditions = @('Core', 'Desktop')
    PowerShellVersion    = '5.1'

    GUID                 = '6c8d0f82-aec0-43a7-a85a-8e77324c8fca'

    Author               = 'Freddie Sackur'
    CompanyName          = 'DustyFox'
    Copyright            = '(c) 2023 Freddie Sackur. All rights reserved.'

    RootModule           = 'MiCasa.psm1'

    AliasesToExport      = @()
    FunctionsToExport    = @(
        '*'
    )

    FormatsToProcess     = @()

    PrivateData          = @{
        PSData = @{
            LicenseUri = 'https://raw.githubusercontent.com/fsackur/MiCasa/main/LICENSE'
            ProjectUri = 'https://github.com/fsackur/MiCasa'
            Tags       = @(
                'Chezmoi',
                'Dotfiles',
                'Config',
                'MiCasa',
                'MiCasa-Elements'
            )
        }
    }
}

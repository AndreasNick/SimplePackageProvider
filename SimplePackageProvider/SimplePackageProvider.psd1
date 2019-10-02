@{
RootModule = 'SimplePackageProvider.psm1'
ModuleVersion = '0.1.0'
GUID = '8f830cf9-07d8-429f-9064-4c30cea23c1b'
Author = 'Patrik Horn, Andreas Nick'
CompanyName = 'Software-Virtualisierung'
Copyright = '© 2019 All rights reserved.'
Description = 'SimplePackageProvider is es simple Provider to install msi Packages'
PowerShellVersion = '3.0'
FunctionsToExport = @()
#RequiredModules = @('PackageManagement')
PrivateData = @{"PackageManagementProviders" = 'SimplePackageProvider.psm1'

    PSData = @{

        # Tags applied to this module to indicate this is a PackageManagement Provider.
        Tags = @("PackageManagement","Provider")

        # A URL to the license for this module.
        LicenseUri = ''

        # A URL to the main website for this project.
        ProjectUri = 'https://www.Software-Virtualisierung.de'

        # ReleaseNotes of this module
        ReleaseNotes = ''
        
        } # End of PSData
    }
}


<#
    Das Grundgerüst stammt aus dem Microsoft Beispiel MyAdlbum
    https://www.powershellgallery.com/packages/MyAlbum
#>

# Provider name
$script:ProviderName = "SimplePackageProvider"

# The folder where stores the provider configuration file
$script:LocalPath = "$env:LOCALAPPDATA\Contoso\$script:ProviderName"
[Hashtable] $script:RegisteredPackageSources = $null    
$script:RegisteredPackageSourcesFilePath = Microsoft.PowerShell.Management\Join-Path -Path $script:LocalPath -ChildPath "MyAlbumPackageSource.xml"

# Wildcard pattern matching configuration
$script:wildcardOptions = [System.Management.Automation.WildcardOptions]::CultureInvariant -bor `
    [System.Management.Automation.WildcardOptions]::IgnoreCase


<#
.SYNOPSIS
Mandatory function for the PackageManagement providers. It returns the name of your provider.
#>

function Get-PackageProviderName { 
    return $script:ProviderName
}

<#
.SYNOPSIS
Mandatory function for the PackageManagement providers. It initializes your provider before performing any actions.
#>

function Initialize-Provider { 

    Write-Verbose $('Initialize-Provider')
    $script:RegisteredPackageSources = [ordered]@{ }
    #add your intialize code here
}

<#
.SYNOPSIS
Optional function that gets called when the user is registering a package source
#>
function Add-PackageSource {
    [CmdletBinding()]
    param
    (
        [string]
        $Name,
         
        [string]
        $Location,

        [bool]
        $Trusted
    )     
    
    Write-Verbose ('Add-PackageSource')
    #ToDo validate Parameter
    $packageSource = Microsoft.PowerShell.Utility\New-Object PSCustomObject -Property ([ordered]@{
            Name               = $Name
            SourceLocation     = $Location.TrimEnd("\") 
            Trusted            = $Trusted
            Registered         = $true
            InstallationPolicy = if ($Trusted) { 'Trusted' } else { 'Untrusted' }   #####       
        })    

    $script:RegisteredPackageSources.Add($Name, $packageSource)
    #Write-Verbose $("OUT---> " + $script:RegisteredPackageSources[$Name] )
    Write-Verbose $($Name + " " + $Location)
    Write-Output -InputObject (New-PackageSourceAndYield -Source $packageSource)
}

<#
.SYNOPSIS
 Optional function that unregisters a package Source.
#>
function Remove-PackageSource { 
    param
    (
        [string]
        $Name
    )

    Write-Verbose $('Remove-PackageSource')

    # Check if $Name contains any wildcards
    if (Test-WildcardPattern $Name) {
        $message = "PackageSourceNameContainsWildCards " + $Name
        Write-Error -Message $message -ErrorId "PackageSourceNameContainsWildCards" -Category InvalidOperation -TargetObject $Name
        return
    }

    # Error out if the specified source name is not in the registered package sources.
    if (-not $script:RegisteredPackageSources.Contains($Name)) {
        $message = "Package Source Not Found $Name"
        Write-Error -Message $message -ErrorId "PackageSourceNotFound" -Category InvalidOperation -TargetObject $Name
        return
    }

    # Remove the SourcesToBeRemoved
    $script:RegisteredPackageSources.Remove($Name) 
    Write-Verbose $("Remove $Name")
}

<#
.SYNOPSIS
This is an optional function that returns the registered package sources
#>
function Resolve-PackageSource { 
    Write-Verbose $('Resolve-PackageSource')
    $SourceName = $request.PackageSources

    if (-not $SourceName) {
        $SourceName = "*"
    }

    foreach ($src in $SourceName) {
        if ($request.IsCanceled) { return }

        $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $src, $script:wildcardOptions
        $sourceFound = $false

        $script:RegisteredPackageSources.GetEnumerator() | 
            Where-Object { $wildcardPattern.IsMatch($_.Key) } | 
            ForEach-Object {
                $source = $script:RegisteredPackageSources[$_.Key]
                $packageSource = New-PackageSourceAndYield -Source $source
                Write-Output -InputObject $packageSource
                $sourceFound = $true
            }
        if (-not $sourceFound) {    
            $sourceName = Get-SourceName -Location $src
            if ($sourceName) {
                $source = $script:RegisteredPackageSources[$sourceName]
                $packageSource = New-PackageSourceAndYield -Source $source
                Write-Output -InputObject $packageSource
            } 
       
            elseif ( -not ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($src))) {
                $message = "Package Source Not Found $src"
                Write-Error -Message $message -ErrorId "PackageSourceNotFound" -Category InvalidOperation -TargetObject $src
            }
        }
    }
}

# Optional function that finds packages by given name and version information. 
# It is required to implement this function for the providers that support find-package. For example, find-package -ProviderName  MyAlbum -Source demo.
function Find-Package { 
    param(
        [string] $name,
        [string] $requiredVersion,
        [string] $minimumVersion,
        [string] $maximumVersion
    )

    $pattern = $name
    if ($name -eq "") { $pattern = "*" }
    
    Write-Verbose $('Find-Package for pattern: ' + $pattern)

    $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $pattern, $script:wildcardOptions
    
    if ($script:RegisteredPackageSources.count -eq 0) {
        Write-Verbose "No package source directory in the repository"
    }

    foreach ($Source in $script:RegisteredPackageSources.Values) {
        $Directory = $Source.SourceLocation
        $packages = Get-ChildItem "$Directory\*.xml" | Where-Object { $wildcardPattern.IsMatch($_.name) }
        
        #Write-Verbose $("Packages :" + $packages)

        foreach ($item in $packages) { 

            if ($request.IsCanceled) { return }

            $swidObject = @{
                FastPackageReference = $item.name #$pkgname+"#" + $pkgversion;
                Name                 = $item.name;
                Version              = "1.0.0.0";
                versionScheme        = "MultiPartNumeric";
                Source               = $Directory;         
            }
            $sid = New-SoftwareIdentity @swidObject              
            Write-Output -InputObject $sid   
        }
    }
}

function Install-Package { 
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fastPackageReference
    )

    Write-Verbose $('Install-Package')
    <#
    Write-Debug -Message ($LocalizedData.FastPackageReference -f $fastPackageReference)
    $path = Get-Path -Request $request
    
    #>
}

function UnInstall-Package { 
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fastPackageReference
    )

    Write-Verbpse $('Uninstall-Package')
    Write-Verbose $fastPackageReference
    $fileFullName = $fastPackageReference

    <#
    if(Test-Path -Path $fileFullName)
    {
        Remove-Item $fileFullName -Force -WhatIf:$false -Confirm:$false

        $swidObject = @{
            FastPackageReference = $fileFullName;                        
            Name = [System.IO.Path]::GetFileName($fileFullName);
            Version = New-Object System.Version ("0.1");  # Note: You need to fill in a proper package version    
            versionScheme  = "MultiPartNumeric";              
            summary = "Summary of your package provider"; 
            Source =   [System.IO.Path]::GetDirectoryName($fileFullName)                             
        }

        $swidTag = New-SoftwareIdentity @swidObject
        Write-Output -InputObject $swidTag
    }
    #>	 
}


# Optional function that returns the packages that are installed. However it is required to implement this function for the providers 
# that support Get-Package. It's also called during install-package.
# For example, Get-package -Destination c:\myfolder -ProviderName MyAlbum
function Get-InstalledPackage { 
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [string]
        $MinimumVersion,

        [Parameter()]
        [string]
        $MaximumVersion
    )

    Write-Verbose $('Get-InstalledPackage ' + $Name)

    $wildcardPattern = New-Object System.Management.Automation.WildcardPattern $Name, $script:wildcardOptions
    
    if ($script:RegisteredPackageSources.count -eq 0) {
        Write-Verbose "No package source directory in the repository"
        return
    }

    foreach ($Source in $script:RegisteredPackageSources.Values) {
        $Directory = $Source.SourceLocation
        $packages = Get-ChildItem "$Directory\*.xml" | Where-Object { $wildcardPattern.IsMatch($_.name) }
        foreach ($item in $packages) { 

            if ($request.IsCanceled) { return }
            [xml] $pfile = New-Object xml
            $pfile.load($item.FullName)
            Write-Verbose $("Detect " + $pfile.package.DetectInstall)
            if (Test-Path $pfile.package.DetectInstall) {

                $swidObject = @{
                    FastPackageReference = $item.name #$pkgname+"#" + $pkgversion;
                    Name                 = $item.name;
                    Version              = "1.0.0.0";
                    versionScheme        = "MultiPartNumeric";
                    summary = "Summary of the simple package provider";
                    Source               = $Directory;         
                }
                $sid = New-SoftwareIdentity @swidObject              
                Write-Output -InputObject $sid  
            }
 
        }
    }


}

#region Helper functions

# Find package source name from a given location
function Get-SourceName {
    [CmdletBinding()]
    [OutputType("string")]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Location
    )

    #Set-PackageSourcesVariable

    foreach ($source in $script:RegisteredPackageSources.Values) {
        if ($source.SourceLocation -eq $Location) {
            return $source.Name
        }
    }
}

function New-PackageSourceAndYield {
    param
    (
        [Parameter(Mandatory)]
        $Source
    )
     
    # create a new package source
    $src = New-PackageSource -Name $Source.Name `
        -Location $Source.SourceLocation `
        -Trusted $Source.Trusted `
        -Registered $Source.Registered `

    Write-Verbose $( "Package Source Details " + $src.Name + " " + $src.Location + " " + $src.IsTrusted + " " + $src.IsRegistered) 

    Write-Output -InputObject $src
}

#endregion

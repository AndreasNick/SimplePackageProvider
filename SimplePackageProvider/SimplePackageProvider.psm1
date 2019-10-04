 <#
    Das Grundgerüst stammt aus dem Microsoft Beispiel MyAdlbum
    https://www.powershellgallery.com/packages/MyAlbum
#>

# Provider name
$script:ProviderName = "SimplePackageProvider"

# The folder where stores the provider configuration file
[Hashtable] $script:RegisteredPackageSources = $null    #All Source Pathes

# Wildcard pattern matching configuration
$script:wildcardOptions = [System.Management.Automation.WildcardOptions]::CultureInvariant -bor [System.Management.Automation.WildcardOptions]::IgnoreCase

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
    
    Write-Verbose $('Add-PackageSource ' + $Name)
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

<#
.SYNOPSIS
finds packages by given name and version information. 

.DESCRIPTION
 Optional function that finds packages by given name and version information. 
 It is required to implement this function for the providers that support find-package. For example, find-package -ProviderName  MyAlbum -Source demo.


.PARAMETER name


.PARAMETER requiredVersion

.PARAMETER minimumVersion

.PARAMETER maximumVersion

.EXAMPLE
An example

.NOTES
General notes
#>

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
                Source               = Join-Path $Directory -ChildPath $item.name;         
            }
            $sid = New-SoftwareIdentity @swidObject              
            Write-Output -InputObject $sid   
        }
    }
}

<#
.SYNOPSIS
Install a Package

.DESCRIPTION
Install a PackageManager Package

.PARAMETER fastPackageReference


.EXAMPLE


.NOTES

#>

function Install-Package { 
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fastPackageReference
    )

    Write-Verbose $('Install-Package ' + $fastPackageReference)
    
    if ($script:RegisteredPackageSources.count -eq 0) {
        Write-Verbose "No package source directory in the repository"
        return
    }
    $InstallXML = $null
    $Packagepath = ""
    foreach ($Source in $script:RegisteredPackageSources.Values) {
        $Directory = $Source.SourceLocation
        if (Test-Path (Join-Path $Directory -ChildPath $fastPackageReference)) {
            $InstallXML = New-Object xml
            $InstallXML.Load((Join-Path $Directory -ChildPath $fastPackageReference))
            $Packagepath = $Directory 
            break #one is enough
        }
    }
    #Is already installed?
    if (Test-Path $InstallXML.package.DetectInstall) {
        Write-Warning $('The Package' + $fastPackageReference + " is already installed - abort")

    }
    else {
        if ($null -ne $InstallXML ) {

            $Parameter = $InstallXML.package.Install
            $msifilepath = $Packagepath + "\packages\" + $InstallXML.package.msi
            if (-not (Test-Path $msifilepath)) {
                Write-Error "msi Package $msifilepath not found"
                break;       
            }
            $DataStamp = get-date -Format yyyyMMddTHHmmss
            $logFile = $("$env:temp" + ('\{0}-{1}.log' -f $file.fullname, $DataStamp))
            $MSIArguments = @("/norestart", "/L*v", $logFile, $Parameter, $msifilepath)
        
            Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow 
            #ToDo: Errorhandling
            if (-not (Test-Path $InstallXML.package.DetectInstall)) {
                Write-Error $('Error: The Package' + $fastPackageReference + " is not installed")
            }
        }
    }
    $swidObject = @{
        FastPackageReference = $fastPackageReference;
        Name                 = $fastPackageReference;
        Version              = "1.0.0.0"; #need Detect Version or version in the xml
        versionScheme        = "MultiPartNumeric";              
        summary              = "Summary"; 
        Source               = Join-Path $Directory -ChildPath $fastPackageReference      
    }
    #Write-Verbose "$fastPackageReference"
    $swidTag = New-SoftwareIdentity @swidObject
    Write-Output -InputObject $swidTag
    
}

<#
.SYNOPSIS
Uninstall a Package

.DESCRIPTION


.PARAMETER fastPackageReference


.EXAMPLE


.NOTES

#>

function UnInstall-Package { 
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $fastPackageReference
    )

    Write-Verbose $('Uninstall-Package')
    #Search for the Package       
    if ($script:RegisteredPackageSources.count -eq 0) {
        Write-Verbose "No package source directory in the repository"
        return
    }
    $InstallXML = $null
    $Packagepath = ""
    foreach ($Source in $script:RegisteredPackageSources.Values) {
        $Directory = $Source.SourceLocation
        if (Test-Path (Join-Path $Directory -ChildPath $fastPackageReference)) {
            $InstallXML = New-Object xml
            $InstallXML.Load((Join-Path $Directory -ChildPath $fastPackageReference))
            $Packagepath = $Directory 
            break #one is enough
        }
    }
    
    #Is not installed?
    if (-not (Test-Path $InstallXML.package.DetectInstall)) {
        Write-Warning $('The Package' + $fastPackageReference + " is not installed - abort")

    }
    else {
        if ($null -ne $InstallXML ) {

            $Parameter = $InstallXML.package.Remove
            $msifilepath = $Packagepath + "\packages\" + $InstallXML.package.msi
            if (-not (Test-Path $msifilepath)) {
                Write-Error "msi Package $msifilepath not found"
                break;       
            }
            $DataStamp = get-date -Format yyyyMMddTHHmmss
            $logFile = $("$env:temp" + ('\{0}-{1}.log' -f $file.fullname, $DataStamp))
            $MSIArguments = @("/norestart", "/L*v", $logFile, $Parameter, $msifilepath)
        
            Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow 
            #ToDo: Errorhandling
            if (Test-Path $InstallXML.package.DetectInstall) {
                Write-Error $('Error: The Package' + $fastPackageReference + " is not removed")
            }
        }
    }
    $swidObject = @{
        FastPackageReference = $fastPackageReference;
        Name                 = $fastPackageReference;
        Version              = "1.0.0.0"; #need Detect Version or version in the xml
        versionScheme        = "MultiPartNumeric";              
        summary              = "Summary"; 
        Source               = Join-Path $Directory -ChildPath $fastPackageReference      
    }
    #Write-Verbose "$fastPackageReference"
    $swidTag = New-SoftwareIdentity @swidObject
    Write-Output -InputObject $swidTag
   

}


#
<#
.SYNOPSIS
 Returns the packages that are installed

.DESCRIPTION
 Optional function that returns the packages that are installed. However it is required to implement this function for the providers 
 that support Get-Package. It's also called during install-package.
 For example, Get-package -Destination c:\myfolder -ProviderName MyAlbum

.PARAMETER Name
Parameter description

.PARAMETER RequiredVersion
Parameter description

.PARAMETER MinimumVersion
Parameter description

.PARAMETER MaximumVersion
Parameter description
#>

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
                    summary              = "Summary";
                    Source               = Join-Path $Directory -ChildPath $item.FullName;         
                }
                #Write-Verbose $("Detected " + $pfile.package.DetectInstall)

                $sid = New-SoftwareIdentity @swidObject              
                #Write-Verbose  $($item.name )
                Write-Output -InputObject $sid  
                
            }
 
        }
    }


}

<#
.SYNOPSIS
# Find package source name from a given location

.DESCRIPTION


.PARAMETER Location
Parameter description

.EXAMPLE


.NOTES

#>

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



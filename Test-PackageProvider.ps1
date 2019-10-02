
#PackageManagement in the PowerShell Gallery
#https://www.powershellgallery.com/packages/PackageManagement
#PackageManagement is a new way to discover and install software packages from around the web.

#$PSScriptRoot not working in VSCode or ISE
$Script:PathToScript = $null
if ($psISE) { $PathToScript = Split-Path -Path $psISE.CurrentFile.FullPath }
else {
    if ($profile -match "VScode") {
        $PathToScript = split-path $psEditor.GetEditorContext().CurrentFile.Path
    } 
    else {
        $PathToScript = $PSScriptRoot
    }
}

Write-Host  $('Use root path :' + $PathToScript)
break



#PackageManagement is integrated in Windows 10
Get-Command -Module PackageManagement

<#

    Cmdlet          Get-PackageProvider                                
    Cmdlet          Get-PackageSource                                  
    Cmdlet          Import-PackageProvider                             
    Cmdlet          Install-Package                                    
    Cmdlet          Install-PackageProvider                            
    Cmdlet          Register-PackageSource                             
    Cmdlet          Save-Package                                       
    Cmdlet          Set-PackageSource                                  
    Cmdlet          Uninstall-Package                                  
    Cmdlet          Unregister-PackageSource                           


#>
#Providers in New Windows 10
Get-PackageProvider
<#
Name                     Version          DynamicOptions
----                     -------          --------------
msi                      3.0.0.0          AdditionalArguments
msu                      3.0.0.0
PowerShellGet            1.0.0.1          PackageManagementProvider, Type, Scope, AllowClobber, SkipPublisherC
Programs                 3.0.0.0          IncludeWindowsInstaller, IncludeSystemComponent
#>

#The msi/msu Providers are for "view" installed msi packages
Get-Package -Provider msi
<#
Name                           Version          Source                           ProviderName
----                           -------          ------                           ------------
VMware Tools                   10.3.10.12406962 C:\Program Files\VMware\VMwar... msi
Microsoft Visual C++ 2017 x... 14.12.25810                                       msi
Microsoft Visual C++ 2017 x... 14.12.25810                                       msi
Microsoft Visual C++ 2017 x... 14.12.25810                                       msi
Microsoft Visual C++ 2017 x... 14.12.25810                                       msi
#>

#Nice filters
Get-Package -Provider msi -MaximumVersion 10.4
<#
Name                           Version          Source                           ProviderName
----                           -------          ------                           ------------
VMware Tools                   10.3.10.12406962 C:\Program Files\VMware\VMwar... msi
#>

#For installing Software
Set-ExecutionPolicy Bypass

# Display installed Programs (appwiz.cpl)
Get-Package -Provider Programs -IncludeWindowsInstallerGet-Package -Provider Programs -IncludeWindowsInstaller

#View installed Updates
Get-Package -Provider msu
Get-Package -Provider  msu | Select-Object -Property Name, status, Summary | Out-GridView

#Only work somtimes: Uninstall-Package to remove the software
Get-Package -Provider Programs -Name *One* | Uninstall-Package -Force #for OneDrive - don't work AppXPackage?

# which, on the other hand, worked.
Get-Package -Provider  msi -Name VMWare* | Uninstall-Package #MSI Package
#This is dangerous!
Get-Package  -Provider msi | Uninstall-Package

#packagesources are sources from which a provider gets its packets. These can be 
#provided in different ways. For example, there is a Chocolatey provider 
# that specifies the Choco website as the source.
get-packagesource

<#
Name                             ProviderName     IsTrusted  Location
----                             ------------     ---------  --------
nuget.org                        NuGet            False      https://api.nuget.org/v3/index.json
PSGallery                        PowerShellGet    False      https://www.powershellgallery.com/api/v2/
#>

#rv * -ea SilentlyContinue; rmo *; $error.Clear(); cls

#Own PackageProvider
$env:PSModulePath = $env:PSModulePath + "; $PathToScript\SimplePackageProvider"
Import-PackageProvider -Name SimplePackageProvider -force -Verbose
Get-PackageProvider
Get-PackageSource

Register-PackageSource -Name "MyRepo" -Location $( $PathToScript + '\Testpackages') -ProviderName "SimplePackageProvider" -verbose
Get-PackageSource -Name "MyRepo" | Unregister-PackageSource -Verbose

Find-Package -name "X*" -ProviderName "SimplePackageProvider" -Verbose 

#confirm:$false and -force remove the user prompt
Find-Package -name "X*" -ProviderName "SimplePackageProvider" -Verbose | Install-Package -Confirm:$false -Verbose -Force 




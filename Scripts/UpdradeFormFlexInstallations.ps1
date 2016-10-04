#
# Wrapper script for upgrading all or some FormFlex servers
#

try
{


	Write-Host "Start upgrading FormFlex..." -ForegroundColor Yellow


    $rootPath = split-path -parent $PSScriptRoot;

    # Import upgrade module
	Write-Host "Loading script module..." -ForegroundColor Yellow

    Import-Module "$rootPath\Modules\UpgradeFormFlex.psm1";

    # Get config file
    $upgradeConfig= Get-UpgradeConfig "$rootPath\Config\Config.json";

    # Get artifact file
    $artifactFiles = Get-ArtifactFiles $rootPath

    if(!$artifactFiles)
    {
        return
    }


    # Iterate servers and update one at the time if "IncludedInUpdate" is set to true
    $upgradeConfig.Servers | ForEach-Object { 
    
      $_ | Update-Server -sourceIPAddress $upgradeConfig.SourceIPAddress -artifactFile $artifactFiles[$_.PackageName].FilePath 

    }

}
catch [System.Net.WebException],[System.Exception]
{
    Write-Host "Unhandled exception in Wrapper script" -ForegroundColor Red
}
finally
{
    # Clean-up
    Remove-Module UpgradeFormFlex
    Write-Host "Exit upgrading script" -ForegroundColor Yellow
}


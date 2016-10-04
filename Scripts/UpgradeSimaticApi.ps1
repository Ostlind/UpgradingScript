#
# Upgrade Simatic Api installation
#

$formType = "SimaticWebApi"
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#Create paths to temporary folders
$tempFormTypePath = Join-Path $scriptPath -ChildPath "$($formType)TempFolder"

#Check if this path exists if yes remove it and create a new one
if( Test-Path -Path $tempFormTypePath)
{
    Remove-Item -Path $tempFormTypePath -Recurse -Force
}

#Create temporary folders
$tempFormTypeFolder = New-Item -ItemType Directory -Path $tempFormTypePath

$zipPath = (Get-ChildItem -Path $scriptPath -Recurse -Include "*.zip" | Select-Object -First 1).FullName

#If the zip file is blocked by microsoft unblock it
Unblock-File $zipPath

#Create a shell comobject to make the unzipping
$shell = new-object -ComObject shell.application

if([string]::IsNullOrEmpty($zipPath))
{
    Write-Host "Could not find any zip file" -ForegroundColor Red
    Break;
}

try
{
    #
    # Unpack artifact
    #
    Write-Host "Unzipping artifact..." -ForegroundColor Green

    $zip = $shell.NameSpace($zipPath)

    foreach( $item in $zip.Items())
    {
        $childPath = Split-Path $item.Path -Leaf
    
        # Lab
        if( $childPath -eq $formType)
        {
            $shell.Namespace($tempFormTypeFolder.FullName).copyhere($item)
        }
    }

    #
    # Replacing client files
    #
    $formPartTempFullPath = Join-Path $tempFormTypeFolder.FullName -ChildPath "$formType\"


    
    if(Test-Path $formPartTempFullPath)
    {
        # Replacing SimaticApi files
        Write-Host "Replacing Simatic Web Api files..." -ForegroundColor Green

        $SimaticWebApiPath =  Join-Path $scriptPath "Af.SimaticIt.WebApi\"
        
        $itemsToRemove = Get-ChildItem $SimaticWebApiPath -Directory
        
        $itemsToRemove | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Copy-Item  "$formPartTempFullPath\*" -Destination "$SimaticWebApiPath" -Container -Recurse -Force
    }
    else
    {
        Write-Host "The folder $( Split-Path $formPartTempFullPath -Leaf) does not exist in $($zipPath), Sim is not updated" -ForegroundColor Yellow
    }                   
    # The -Container switch will preserve the folder structure, The -Recurse switch will go through all folders..wait for it....recursively  
   
}
catch [System.Net.WebException],[System.Exception]
{
	Write-Host "Unhandled exception in UpgradeFas script" -ForegroundColor Red
	Write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red | Tee-Object -FilePath ./errorLog.txt 
}
finally
{
    Remove-Item $tempFormTypeFolder -Recurse -Force
}

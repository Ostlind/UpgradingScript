
<#
.Synopsis
   Get config file with information about servers etc
.DESCRIPTION
   Long description
.EXAMPLE
   Get-UpgradeConfig .\ServersToUpgrade.json
#>
function Get-UpgradeConfig
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        # Path to config file
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [string]
        $Path
    )

    Begin
    {
		Write-Host "Loading configuration..." -ForegroundColor Yellow
    }
    Process
    {
        try
        {
			
            # Get config file with servers to upgrade
            $configFile = Get-Content $Path -Raw

            # Abort if no config file
            if ([string]::IsNullOrEmpty($configFile)){
                Write-Host "Could not find config file! Script is aborted!" -ForegroundColor Red
                return;
            }

            # Convert to object
            $config = ConvertFrom-Json $configFile;

            # Return
            return $config;

        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Host "Unhandled exception in Get-UpgradeConfig" -ForegroundColor Red
        }
        finally
        {
        }
    }
}

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-ArtifactFile
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   
                   Position=0)]
        $Path,

        [Parameter(Mandatory=$true,
                   
                   Position=1)]
        $Regex
    )

    Process
    {
    
        try
        {
        
            $foundArtifacts =   Get-ChildItem -Path $Path -Include "*.zip" -Recurse | ForEach-Object { 
										
                                        if( ($_.FullName -Match $Regex ))
										{ 
											return @{ FilePath = $_.Name; buildvcsnumber = [int]$Matches.buildvcsnumber; } 
										}
								   } | Sort-Object { $_.buildvcsnumber } -Descending  


            if ($foundArtifacts -eq $null)
		    {
                Write-Host "No package found in '$Path' Please add a package and run script again" -ForegroundColor Red

                return $null
    	    }

            $artifactCount = $foundArtifacts.Values.Count / 2

            $isToManyArtifacts = $artifactCount -gt 1

            if($isToManyArtifacts)
            {
                 Write-Host "There are $($artifactCount ) zip packages in '$Path'. Please remove $( $artifactCount - 1) package$( @{ $true='s'; $false=''}[ ($artifactCount - 1) -gt 1]) to run the script." -ForegroundColor Red

                 return $null
            }
    	

            return $foundArtifacts
      
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Host "Unhandled exception in Get-ArtifactFile" -ForegroundColor Red
        }
        finally
        {
        } 
    }
}

<#
.Synopsis
   Get latest artifact file
.DESCRIPTION
   Long description
.EXAMPLE
   Get-ArtifactFile 
.INPUTS
   Script execution path
#>
function Get-ArtifactFiles
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [string]
        $Path
    )

    Process
    {
	    try
        {
           $foundArtifacts = @{};

		   Write-Host "Searching for the latest upgrade zip package..." -ForegroundColor Yellow

           $foundArtifact = Get-ArtifactFile -Path $Path -Regex "(?<packagename>\w+)_svn_(?<buildvcsnumber>\d+)"

           if(!$foundArtifact)
           {
              return $null;
           }

           $foundArtifacts.Add("NightlyBuild", $foundArtifact);
           
           #$foundArtifact = Get-ArtifactFile -Path $Path -Regex "(?<packagename>RDM_Upgrade)_Svn_(?<buildvcsnumber>\d+)"
            
           #$foundArtifacts.Add("Reports", $foundArtifact);

		   return $foundArtifacts
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Host "Unhandled exception in Get-ArtifactFile" -ForegroundColor Red
        }
        finally
        {
        }
    }
}

<#
.Synopsis
   Upgrade one unique server
.DESCRIPTION
   Long description
.EXAMPLE
   
#>
function Update-Server
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        # The server object specified in config file
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [PSObject]
        $Server,
		# The source IP address
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$false,
                   ValueFromPipelineByPropertyName=$false,
                   Position=1)]
        [string]
        $SourceIPAddress,
		# The artifact file
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$false,
                   ValueFromPipelineByPropertyName=$false,
                   Position=2)]
        [string]
        $ArtifactFile
    )

    Process
    {
		try
        {
			# Return if server is not to be updated
			if ($Server.IncludedInUpdate){
				Write-Host "Updating server - $($Server.Name) - $($Server.FormFlexpart)..." -ForegroundColor Yellow
			}
			else
			{
				Write-Host "$($Server.Name) - $($Server.FormFlexpart) -  is not set to be updated!" -ForegroundColor Yellow
				return
			}

			$InstallationPath = $Server.InstallPath
			$FormFlexPart = $Server.FormFlexPart
			$DestinationIpAddress = $Server.IPAddress
            
            $Domain = [string]::Empty

            if(![string]::IsNullOrEmpty($Server.Domain ))
            {
              $Domain = $Server.Domain
            }
            else
            {
              $Domain = $DestinationIpAddress
            }

            if( ![string]::IsNullOrEmpty($Server.UserName) -and ![string]::IsNullOrEmpty($Server.Password))
            {
                $RemoteUser = "$Domain\$($server.UserName)"
			    $RemotePWord = ConvertTo-SecureString -String $server.Password -AsPlainText -Force
			    $RemoteCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RemoteUser, $RemotePWord

            }
            elseif( ![string]::IsNullOrEmpty($Server.UserName) -and [string]::IsNullOrEmpty($Server.Password))
            {
            
                $RemoteUser = "$Domain\$($server.UserName)"
                $RemoteCredential = Get-Credential -UserName $RemoteUser -Message  "Please enter your username and password"

            }
            else
            {
			  $RemoteCredential = Get-Credential -Message "Please enter your username and password"
            }
	        
            if(!$RemoteCredential)
            {
                Write-Output "You didn't entered valid credentials" | Out-File -FilePath $Global:tempFilePath
                return
            }
	
			$Session = New-PSSession -cn $DestinationIpAddress -Credential $RemoteCredential

            #
            # Everything in this ScriptBlock is executed on the remote server
			#
            Invoke-Command  -Session $session -ScriptBlock {
			   param ($installationPath, $formFlexPart, $sourceIpAddress, $upgradePackage, $localCredential, $artifactFile)

                #Set-PSBreakpoint -Variable Break

                #$Break = $null

				Write-Host "Mapping source file location..." -ForegroundColor Yellow
				New-PSDrive -Name I -PSProvider FileSystem -Root ('\\' + $sourceIpAddress +'\Install') -Credential $localCredential

				Write-Host "Removing old installation files..." -ForegroundColor Yellow
				
                Remove-Item "$installationPath\MigrateTempFolder" -Recurse -ErrorAction SilentlyContinue
				
                Get-ChildItem "$installationPath\" -Include *.ps1,*.zip -Recurse | Remove-Item

				Write-Host "Copying new installation files..." -ForegroundColor Yellow
				Copy-Item -Path "I:\$artifactFile" -Destination $installationPath
				switch ($formFlexPart)
				{
					"Fas" { Copy-Item -Path "I:\Scripts\UpgradeFas.ps1" -Destination $installationPath; Break }
					"Fls" { Copy-Item -Path "I:\Scripts\UpgradeFls.ps1" -Destination $installationPath; Break }
					"Lab" { Copy-Item -Path "I:\Scripts\UpgradeLab.ps1" -Destination $installationPath; Break }
                    "Rew" { Copy-Item -Path "I:\Scripts\UpgradeRew.ps1" -Destination $installationPath; Break }
                    "Sim" { Copy-Item -Path "I:\Scripts\UpgradeSimaticApi.ps1" -Destination $installationPath; Break }
                    "Etl" { Copy-Item -Path "I:\Scripts\MoveEtl.ps1"    -Destination $installationPath; Break }
                    "Rdm" { Copy-Item -Path "I:\Scripts\UpgradeRdm.ps1" -Destination $installationPath;
                            Copy-Item -Path "I:\Scripts\Initialize-SqlPsEnvironment.ps1" -Destination $installationPath; Break }
				}

				# Run upgrade script
				Write-Host "Updating files..." -ForegroundColor Yellow

				switch ($formFlexPart)
				{
					"Fas" { . "$installationPath\UpgradeFas.ps1"; Break }
					"Fls" { . "$installationPath\UpgradeFls.ps1"; Break }
					"Lab" { . "$installationPath\UpgradeLab.ps1"; Break }
					"Rew" { . "$installationPath\UpgradeRew.ps1"; Break }
					"Sim" { . "$installationPath\UpgradeSimaticApi.ps1"; Break }
                    "Etl" { . "$installationPath\MoveEtl.ps1";    Break }
                    "Rdm" { . "$installationPath\UpgradeRdm.ps1"; Break }
                    
				}

				Write-Host "Unmapping source file location..." -ForegroundColor Yellow
				
                Remove-PSDrive -Name I

			} -ArgumentList $InstallationPath, $FormFlexPart, $SourceIpAddress, $UpgradePackage, $RemoteCredential, $ArtifactFile

			Remove-PSSession -Session $Session
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Host "Unhandled exception in Update-Server" -ForegroundColor Red
        }
        finally
        {

        }
    }
}

# Import IBM WebSphere App Server Utils Module
Import-Module $PSScriptRoot\cIBMWebSphereAppServerUtils.psm1 -ErrorAction Stop
Import-Module PSTokens -ErrorAction Stop -Verbose:$false

enum Ensure {
    Absent
    Present
}

enum WASEdition {
    Base
    ND
    Express
    Developer
    Liberty
}

enum ScopeLevel {
    Cell
    Node
    Server
    Cluster
}

enum ProfileType {
	#Cell
	Default
	#Dmgr
	Managed
	Management
	#Secureproxy
}

<#
   DSC resource to manage the installation of IBM WebSphere Application Server.
   Key features: 
    - Install IBM WebSphere Application Server for the first time
    - Can use media on the local drive as well as from a network share which may require specifying credentials
#>

[DscResource()]
class cIBMWebSphereAppServer {
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Key)]
    [WASEdition] $WASEdition
    
    [DscProperty(Key)]
    [String] $Version
    
    [DscProperty()]
    [String] $InstallationDirectory = "C:\IBM\WebSphere"
    
    [DscProperty()]
    [String] $IMSharedLocation = "C:\IBM\IMShared"
    
    [DscProperty()]
    [String] $InstallMediaConfig
    
    [DscProperty()]
    [String] $ResponseFileTemplate

    [DscProperty()]
    [String] $SourcePath
    
    [DscProperty()]
    [bool] $PlusJava7 = $false
    
    [DscProperty()]
    [System.Management.Automation.PSCredential] $SourcePathCredential

    <#
        Installs IBM WebSphere Application Server
    #>
    [void] Set () {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message "Starting installation of IBM WebSphere Application Server"
                $sevenZipExe = Get-SevenZipExecutable
                if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
                    $ibmwasEdition = $this.WASEdition.ToString()
                    $wasVersion = $this.Version
                    if (!($this.InstallMediaConfig)) {
                        if ($this.PlusJava7) {
                            $this.InstallMediaConfig = Join-Path -Path $PSScriptRoot -ChildPath "InstallMediaConfig\$ibmwasEdition-$wasVersion-plus-JAVA7.xml"
                        } else {
                            $this.InstallMediaConfig = Join-Path -Path $PSScriptRoot -ChildPath "InstallMediaConfig\$ibmwasEdition-$wasVersion.xml"
                        }
                        
                    }
                    if (!($this.ResponseFileTemplate)) {
                        if ($this.PlusJava7) {
                            $this.ResponseFileTemplate = Join-Path -Path $PSScriptRoot -ChildPath "ResponseFileTemplates\$ibmwasEdition-$wasVersion-template-plus-JAVA7.xml"
                        } else {
                            $this.ResponseFileTemplate = Join-Path -Path $PSScriptRoot -ChildPath "ResponseFileTemplates\$ibmwasEdition-$wasVersion-template.xml"
                        }
                    }
                    
                    $installed = Install-IBMWebSphereAppServer -InstallMediaConfig $this.InstallMediaConfig `
                        -ResponseFileTemplate $this.ResponseFileTemplate -InstallationDirectory $this.InstallationDirectory `
                        -IMSharedLocation $this.IMSharedLocation -SourcePath $this.SourcePath -SourcePathCredential $this.SourcePathCredential
                    if ($installed) {
                        Write-Verbose "IBM WebSphere Application Server Installed Successfully"
                    } else {
                        Write-Error "Unable to install IBM WebSphere Application Server, please check installation logs for more information"
                    }
                } else {
                    Write-Error "IBM WebSphere Application Server installation depends on 7-Zip, please ensure 7-Zip is installed first"
                }
            } else {
                Write-Verbose "Uninstalling IBM Application Server (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }

    <#
        Performs test to check if WAS is in the desired state, includes 
        validation of installation directory and version
    #>
    [bool] Test () {
        Write-Verbose "Checking for IBM WebSphere Application Server installation"
        if(Test-IBMPSDscSequenceDebug){return $True}
        $wasConfiguredCorrectly = $false
        $wasRsrc = $this.Get()
        
        if (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Present)) {
            $sameVersion = ($wasRsrc.Version -eq $this.Version)
            if (!($sameVersion)) {
                $currVersionObj = (New-Object -TypeName System.Version -ArgumentList $wasRsrc.Version)
                $newVersionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
                $sameVersion = (($currVersionObj.ToString(3)) -eq ($newVersionObj.ToString(3)))
            }
            if ($sameVersion) {
                if (((Get-Item($wasRsrc.InstallationDirectory)).Name -eq 
                    (Get-Item($this.InstallationDirectory)).Name) -and (
                    (Get-Item($wasRsrc.InstallationDirectory)).Parent.FullName -eq 
                    (Get-Item($this.InstallationDirectory)).Parent.FullName)) {
                    if ($wasRsrc.WASEdition -eq $this.WASEdition) {
                        Write-Verbose "IBM WebSphere Application Server is installed and configured correctly"
                        $wasConfiguredCorrectly = $true
                    }
                }
            }
        } elseif (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Absent)) {
            $wasConfiguredCorrectly = $true
        }

        if (!($wasConfiguredCorrectly)) {
            Write-Verbose "IBM WebSphere Application Server not configured correctly"
        }
        
        return $wasConfiguredCorrectly
    }

    <#
        Leverages the information stored in the registry to populate the properties of an existing
        installation of WAS
    #>
    [cIBMWebSphereAppServer] Get () {
        $RetEnsure = [Ensure]::Absent
        $RetVersion = $null
        $RetWASEdition = $this.WASEdition
        
        $versionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
        $RetInsDir = Get-IBMWebSphereAppServerInstallLocation $this.WASEdition $versionObj
        
        if($RetInsDir -and (Test-Path($RetInsDir))) {
            $VersionInfo = Get-IBMWebSphereProductVersionInfo $RetInsDir
            $ibmwasEdition = $this.WASEdition.ToString()
            if($VersionInfo -and ($VersionInfo.Products) -and ($VersionInfo.Products[$ibmwasEdition])) {
                Write-Verbose "IBM WebSphere Application Server is Present"
                $RetEnsure = [Ensure]::Present
                $RetVersion = $VersionInfo.Products[$ibmwasEdition].Version
            } else {
                Write-Warning "Unable to retrieve version information from the IBM WebSphere Application Server installed"
            }
        } else {
            Write-Verbose "IBM WebSphere Application Server is NOT Present"
        }

        $returnValue = @{
            InstallationDirectory = $RetInsDir
            Version = $RetVersion
            WASEdition = $RetWASEdition
            Ensure = $RetEnsure
        }

        return $returnValue
    }
}

[DscResource()]
class cIBMWebSphereAppServerFixpack {
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Key)]
    [WASEdition] $WASEdition
    
    [DscProperty(Key)]
    [String] $Version
    
    [DscProperty()]
    [String] $WebSphereInstallationDirectory = "C:\IBM\WebSphere\"
    
    [DscProperty(Mandatory)]
    [PSCredential] $WebSphereAdministratorCredential
    
    [DscProperty()]
    [String[]] $SourcePath
    
    [DscProperty()]
    [PSCredential] $SourcePathCredential

    <#
        Installs IBM WebSphere Application Server Fixpack
    #>
    [void] Set () {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message "Starting installation of IBM WAS Fixpack"
                $sevenZipExe = Get-SevenZipExecutable
                if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
                    $versionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
                    $installed = Install-IBMWebSphereAppServerFixpack -Version $versionObj `
                        -WASEdition $this.WASEdition -WebSphereInstallationDirectory $this.WebSphereInstallationDirectory `
                        -SourcePath $this.SourcePath -SourcePathCredential $this.SourcePathCredential `
                        -WebSphereAdministratorCredential $this.WebSphereAdministratorCredential
                    if ($installed) {
                        Write-Verbose ("IBM WAS Fixpack " + $this.Version + "Installed Successfully")
                    } else {
                        Write-Error "Unable to install the IBM WAS Fixpack, please check installation logs for more information"
                    }
                } else {
                    Write-Error "IBM WAS Fixpack installation depends on 7-Zip, please ensure 7-Zip is installed first"
                }
            } else {
                Write-Verbose "Uninstalling IBM WAS Fixpack (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }

    <#
        Performs test to check if WAS fixpack is alreay installed
    #>
    [bool] Test () {
        Write-Verbose "Checking for IBM WAS Fixpack installation"
        if(Test-IBMPSDscSequenceDebug){return $True}
        $wasConfiguredCorrectly = $false
        $wasRsrc = $this.Get()
        
        if (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Present)) {
            if ($wasRsrc.Version -eq $this.Version) {
                if (((Get-Item($wasRsrc.WebSphereInstallationDirectory)).Name -eq 
                    (Get-Item($this.WebSphereInstallationDirectory)).Name) -and (
                    (Get-Item($wasRsrc.WebSphereInstallationDirectory)).Parent.FullName -eq 
                    (Get-Item($this.WebSphereInstallationDirectory)).Parent.FullName)) {
                    if ($wasRsrc.WASEdition -eq $this.WASEdition) {
                        Write-Verbose "IBM WAS Fixpack is installed"
                        $wasConfiguredCorrectly = $true
                    }
                }
            }
        } elseif (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Absent)) {
            $wasConfiguredCorrectly = $true
        }

        if (!($wasConfiguredCorrectly)) {
            Write-Verbose "IBM WAS Fixpack not configured correctly"
        }
        
        return $wasConfiguredCorrectly
    }

    <#
        Leverages versionInfo.bat to get installed fixpack
    #>
    [cIBMWebSphereAppServerFixpack] Get () {
        $RetEnsure = [Ensure]::Absent
        $RetVersion = $null
        $RetWASEdition = $this.WASEdition
        
        $versionObj = (New-Object -TypeName System.Version -ArgumentList $this.Version)
        $RetInsDir = Get-IBMWebSphereAppServerInstallLocation $this.WASEdition $versionObj
        
        if($RetInsDir -and (Test-Path($RetInsDir))) {
            $VersionInfo = Get-IBMWebSphereProductVersionInfo $RetInsDir
            $ibmwasEdition = $this.WASEdition.ToString()
            if($VersionInfo -and ($VersionInfo.Products) -and ($VersionInfo.Products[$ibmwasEdition])) {
                $RetEnsure = [Ensure]::Present
                $RetVersion = $VersionInfo.Products[$ibmwasEdition].Version
            } else {
                Write-Warning "Unable to retrieve version information from the IBM WebSphere Application Server installed"
            }
        } else {
            Write-Verbose "IBM WebSphere Application Server is NOT Present"
        }

        $returnValue = @{
            WebSphereInstallationDirectory = $RetInsDir
            Version = $RetVersion
            WASEdition = $RetWASEdition
            Ensure = $RetEnsure
        }

        return $returnValue
    }
}

[DscResource()]
class cIBMWebSphereAppServerProfile {
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Key)]
    [String] $ProfileName
    
    [DscProperty()]
    [String] $ProfilePath
    
    [DscProperty(NotConfigurable)]
    [String] $WASAppServerHome = $null
    
    [DscProperty(Mandatory)]
    [String] $NodeName
    
    [DscProperty()]
    [String] $CellName
    
    [DscProperty()]
    [String] $HostName
    
    [DscProperty()]
    [String] $TemplatePath
    
    [DscProperty()]
    [Bool] $EnableSecurity = $true
    
    [DscProperty()]
    [String] $ServerName
    
    [DscProperty()]
    [ProfileType] $ProfileType = [ProfileType]::Managed
    
    [DscProperty()]
    [PSCredential] $AdminCredential
    
    [DscProperty()]
    [String] $DmgrHost
    
    [DscProperty()]
    [Int] $DmgrPort = 8879
    
    [DscProperty()]
    [String] $PersonalCertDN
    
    [DscProperty()]
    [String] $SigningCertDN
    
    [DscProperty()]
    [Int] $PersonalCertValidityPeriod = 1
    
    [DscProperty()]
    [Int] $SigningCertValidityPeriod = 15
    
    [DscProperty()]
    [String] $KeyStorePassword
    
    [DscProperty()]
    [String] $NodeAgentName = "nodeagent"
    
    [DscProperty()]
    [Bool] $AppSecurityEnabled = $False
    
	# Populate variables of Profile creation
    [String[]] PopulateArgs(){
    	[String[]] $cmdArgs = @()
    	#Populate Default Args
    	if(!$this.WASAppServerHome){
			$this.WASAppServerHome = Get-IBMWebSphereAppServerInstallLocation ND
    	}
    	if (!$this.ProfilePath) {
	        $this.ProfilePath = Join-Path $this.WASAppServerHome -ChildPath ("profiles\" + $this.ProfileName)
	    }
    	if($this.ProfileType -eq [ProfileType]::Management){
    		$this.ServerName = "dmgr"
            $cmdArgs += ('-serverType', "DEPLOYMENT_MANAGER")
    	}
    	
    	if (!$this.TemplatePath) {
        	$this.TemplatePath = Join-Path $this.WASAppServerHome ("profileTemplates\" + $this.ProfileType.ToString().ToLower()) 
        }


        #Populdate the default Security message if not provided.
		if(!$this.personalCertDN){
            $this.personalCertDN = ('"cn='+$this.HostName+',ou='+$this.CellName+',ou='+$this.NodeName+',o=IBM,c=US"')
        }
        if(!$this.signingCertDN){
            $this.signingCertDN = ('"cn='+$this.HostName+',ou=Root Certificate,ou='+$this.CellName+',ou='+$this.NodeName+',o=IBM,c=US"')
        }
        if(!$this.KeyStorePassword -and $this.AdminCredential){
            $this.KeyStorePassword = $this.AdminCredential.GetNetworkCredential().Password
        }
        
        if($this.personalCertDN){
	        $cmdArgs += ('-personalCertDN', $this.personalCertDN)
        }
        if($this.signingCertDN){
	        $cmdArgs += ('-signingCertDN', $this.signingCertDN)
        }
        if($this.KeyStorePassword){
	        $cmdArgs += ('-keyStorePassword', $this.KeyStorePassword)
        }
        if($this.PersonalCertValidityPeriod){
	        $cmdArgs += ('-personalCertValidityPeriod', $this.PersonalCertValidityPeriod)
        }
        if($this.SigningCertValidityPeriod){
	        $cmdArgs += ('-signingCertValidityPeriod', $this.SigningCertValidityPeriod)
        }
        
        if($this.ProfileType -eq [ProfileType]::Managed){
            if ($this.DmgrHost -and $this.DmgrPort) {
				$cmdArgs += ('-dmgrHost', $this.DmgrHost)
	            $cmdArgs += ('-dmgrPort', $this.DmgrPort)
            }else {
	            Write-Warning "Attempting to create a managed profile without specifying dmgr host/port"
	        }
        }
    	$cmdArgs += ('-templatePath', $this.TemplatePath)
	    $cmdArgs += ('-profileName', $this.ProfileName)
	    $cmdArgs += ('-profilePath', $this.ProfilePath)
	    
	    if ($this.NodeName) {
	        $cmdArgs += ('-nodeName', $this.NodeName)
	    }
	    if ($this.CellName) {
	        $cmdArgs += ('-cellName', $this.CellName)
	    }
	    if ($this.HostName) {
	        $cmdArgs += ('-hostName', $this.HostName)
	    }
	    if ($this.ProfileType -eq [ProfileType]::Default) {
	    	#create server only when it is a default profile
	    	if(!$this.ServerName){
	    		$this.ServerName = "server1"
	    	}
	    	$cmdArgs += ('-serverName', $this.ServerName)
	    }
	    
	    if ($this.AdminCredential) {
	        $adminUserName = $this.AdminCredential.UserName
	        $adminPwd = $this.AdminCredential.GetNetworkCredential().Password
	        
	        # Security wont be enabled for the managed profiles
	        if ($this.EnableSecurity -and ($this.ProfileType -ne [ProfileType]::Managed)) {
				$cmdArgs += ('-enableAdminSecurity', 'true')
		        $cmdArgs += ('-adminUserName', $adminUserName)
		        $cmdArgs += ('-adminPassword', ('"' + $adminPwd + '"'))
	        }
	        
	        # If is not a dmgr profile, you need to specified the dmgr authentication information
	        if (!($this.ProfileType -eq [ProfileType]::Management)) {
	            $cmdArgs += ('-dmgrAdminUserName', $adminUserName)
	            $cmdArgs += ('-dmgrAdminPassword', ('"' + $adminPwd + '"'))
	        }
	        
        }else{
        	Write-Warning "Attempting to create a managed profile without AdminCredential"
        }
	    
	    return $cmdArgs
    }
    
    # Sets the desired state of the resource.
    [void] Set() {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message ("Creating WebSphere Profile: " + $this.ProfileName)
                [bool] $created = $false
                
                $cmdArgs = $this.PopulateArgs()
                
                Write-Verbose -Message ("Creating WebSphere Profile using template: " + $this.TemplatePath)
				
                $created = New-IBMWebSphereProfile -cmdArgs $cmdArgs -ErrorAction Stop
				
				# Populate the Profile Path since it is optional field                
                if (!$this.ProfilePath){
                	$this.ProfilePath = Get-IBMWASProfilePath $this.ProfileName ND
                }
                
				# For Managed Profile, create Windows Service for NODEAGENT
				if ($created -and ($this.ProfileType -eq [ProfileType]::Managed)) {
					#If Server is provided create the WebSphere Application Server
					if($this.ServerName){
						$created = $false
						Write-Verbose -Message ("Creating WebSphere Application Server from Managed Template")
					
						$created = New-WebSphereApplicationServer `
	                				-ProfilePath $this.ProfilePath `
	                				-NodeName $this.NodeName `
	                                -ServerName $this.ServerName `
	                                -DmgrHost $this.DmgrHost `
					                -DmgrPort $this.DmgrPort `
					                -WebSphereAdministratorCredential $this.AdminCredential `
					                -ErrorAction Stop
					}
				}
				
				# If Profile is created with App Server, create windows service for it.
				if($created -and $this.ServerName){
					Write-Verbose -Message ("Creating Windows Service for WAS:"+$this.ServerName)
					$wasWinSvcName = New-IBMWebSphereAppServerWindowsService `
											-ProfilePath $this.ProfilePath `
											-ServerName $this.ServerName `
											-WebSphereAdministratorCredential $this.AdminCredential `
											-WASEdition ND -StartupType Manual
                    Write-Verbose -Message (" Windows Service is created for WAS:"+$wasWinSvcName)
                    # First time stop via batch and restart via windows service
                    Stop-WebSphereServerViaBatch $this.ServerName $this.ProfilePath $this.AdminCredential
                    Start-WebSphereServer -ServerName $this.ServerName -ProfilePath $this.ProfilePath
				}
				
				if ($created -and ($this.ProfileType -eq [ProfileType]::Managed)){
					#Stop the Node Agent
					$stopNodeCmd = Join-Path $this.ProfilePath "bin\stopNode.bat"
					$stopNodeParams = @()
					if ($this.AdminCredential) {
				        $adminUserName = $this.AdminCredential.UserName
				        $adminPwd = $this.AdminCredential.GetNetworkCredential().Password
				        $stopNodeParams += @("-username", $adminUserName)
				        $stopNodeParams += @("-password", $adminPwd)
					}
			        $stopNodeProc = Invoke-ProcessHelper -ProcessFileName $stopNodeCmd -ProcessArguments $stopNodeParams
					if($stopNodeProc -and ($stopNodeProc.exitCode -eq 0)){
                        #Create Windows Service of NodeAgent and start it
                        $nodeAgentSvcName = New-IBMWebSphereAppServerWindowsService `
                                            -ServiceName $this.NodeAgentName `
                                            -ProfilePath $this.ProfilePath `
                                            -ServerName $this.NodeAgentName `
                                            -WebSphereAdministratorCredential $this.AdminCredential `
                                            -WASEdition ND -StartupType Automatic
                        Write-Verbose -Message (" Windows Service is created for NodeAgent and service started:"+$nodeAgentSvcName)
                        # First time stop via batch and then start via windows service
                        if ($this.ServerName) {
                            Stop-WebSphereServer $this.ServerName
                        }
                        Stop-WebSphereNodeAgent -NodeName $this.NodeAgentName `
                                            -ProfileDir $this.ProfilePath `
                                            -WebSphereAdministratorCredential $this.AdminCredential `
                                            -ViaBatch -Verbose -ErrorAction Stop
                        
                        # Now via windows service
                        Start-WebSphereNodeAgent -ProfileDir $this.ProfilePath
                        if ($this.ServerName) {
                            Start-WebSphereServer -ServerName $this.ServerName -ProfilePath $this.ProfilePath
                        }
                    }
				}
				
                if ($created) {
                    if ($this.AdminCredential -and $this.AppSecurityEnabled){
	                	$created = Enable-WebSphereApplicationSecurity $this.ProfilePath $this.AdminCredential
	                }
                    Write-Verbose ("WebSphere profile " + $this.ProfileName + " created/configured successfully")
                } else {
                    Write-Error "Unable to create the WebSphere Profile, please check WAS logs for more information"
                }
            } else {
                Write-Verbose "Uninstalling WebSphere Profile (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }
    
    # Tests if the resource is in the desired state.
    [bool] Test() {
        Write-Verbose "Checking WebSphere Profile configuration"
        if(Test-IBMPSDscSequenceDebug){return $True}
        $profileConfiguredCorrectly = $false
        $wasRsrc = $this.Get()
        
        if (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Present)) {
            if ($wasRsrc.ProfileName -eq $this.ProfileName) {
                if ((!$this.ProfilePath) -or (((Get-Item($wasRsrc.ProfilePath)).Name -eq 
                    (Get-Item($this.ProfilePath)).Name) -and (
                    (Get-Item($wasRsrc.ProfilePath)).Parent.FullName -eq 
                    (Get-Item($this.ProfilePath)).Parent.FullName))) {
                    Write-Verbose "WebSphere profile is configured correctly"
                    $profileConfiguredCorrectly = $true
                }
            }
        } elseif (($wasRsrc.Ensure -eq $this.Ensure) -and ($wasRsrc.Ensure -eq [Ensure]::Absent)) {
            $profileConfiguredCorrectly = $true
        }

        if (!($profileConfiguredCorrectly)) {
            Write-Verbose "WebSphere profile not configured correctly"
        }
        
        return $profileConfiguredCorrectly
    }
    
     # Gets the resource's current state.
    [cIBMWebSphereAppServerProfile] Get() {
        $RetEnsure = [Ensure]::Absent
        $RetProfileName = $null
        $RetProfilePath = $null
        
        $RetInsDir = Get-IBMWebSphereAppServerInstallLocation ND
        Write-Verbose "WAS is installed at: $RetInsDir"
        if($RetInsDir -and (Test-Path($RetInsDir))) {
        	try{
	        	$RetProfilePath = Get-IBMWASProfilePath $this.ProfileName ND -ErrorAction SilentlyContinue
        	}catch{
        	#bypass exception
        		
        	}
            if ($RetProfilePath -and (Test-Path $RetProfilePath)) {
            	$RetProfileName = $this.ProfileName
            	$RetEnsure = [Ensure]::Present
            	Write-Verbose "Found Existing Profile $RetProfileName at $RetProfilePath"
            } else {
                Write-Verbose ("No profiles found : "+$this.ProfileName)
            }
        } else {
            Write-Verbose "IBM WebSphere Application Server is NOT Present"
        }
        
        return $returnValue = @{
            WASAppServerHome = $RetInsDir
            ProfileName = $RetProfileName
            ProfilePath = $RetProfilePath
            Ensure = $RetEnsure
        }
    }
}

<#
   DSC resource to manage JVM settings of an IBM WebSphere Application Server.
#>

[DscResource()]
class cIBMWebSphereJVMSettings {
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Mandatory)]
    [String] $ProfileName
    
    [DscProperty(Key)]
    [String] $ServerName
    
    [DscProperty(Mandatory)]
    [String] $NodeName
    
    [DscProperty(Mandatory)]
    [String] $CellName
    
    [DscProperty()]
    [Int] $MinHeapSize = 1024
    
    [DscProperty()]
    [Int] $MaxHeapSize = 2048
    
    [DscProperty()]
    [HashTable] $CustomProperties = @{}
    
    [DscProperty()]
    [Boolean] $VerboseGC = $false
    
    [DscProperty(Mandatory)]
    [PSCredential] $WebSphereAdministratorCredential
    
    <#
        Applies the JVM Settings
    #>
    [void] Set () {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message ("Applying WebSphere JVM settings")
                $profilePath = Get-IBMWASProfilePath $this.ProfileName
                if ($profilePath) {
                    $varData = $this.InitializeVariableData()
                    $configApplied = Set-IBMWebSpherePropertyBasedConfig -ProfilePath $profilePath `
                            -VariablesMap $varData -PropertyFile $this.GetPBCTemplatePath() `
                            -WebSphereAdministratorCredential $this.WebSphereAdministratorCredential
                    if ($configApplied) {
                        Write-Verbose "Configuration applied successfully, restarting server"
                        Stop-WebSphereServerViaBatch $this.ServerName $profilePath $this.WebSphereAdministratorCredential
                        Start-WebSphereServerViaBatch $this.ServerName $profilePath
                    }
                } else {
                    Write-Error "Invalid WebSphere Profile: $profilePath"
                }
            } else {
                Write-Verbose "Removing configuration (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }

    <#
        Performs test to check if the WAS JVM has the desired state
    #>
    [bool] Test () {
        Write-Verbose "Checking for WebSphere JVM Settings"
        if(Test-IBMPSDscSequenceDebug){return $True}
        $profilePath = Get-IBMWASProfilePath $this.ProfileName
        $varData = $this.InitializeVariableData()
        if (!(Test-WebSphereServerService $this.ServerName)) {
            Start-WebSphereServerViaBatch $this.ServerName $profilePath
        }
        $wasConfiguredCorrectly = Test-IBMWebSpherePropertyBasedConfig -ProfilePath $profilePath `
                -VariablesMap $varData -PropertyFile $this.GetPBCTemplatePath() `
                -WebSphereAdministratorCredential $this.WebSphereAdministratorCredential
        return $wasConfiguredCorrectly
    }
    
	[String] FormateToPropString(){
		if(!$this.CustomProperties){
			return $Null
		}
		
		return ($this.CustomProperties.Keys | foreach { $key = $_;"$key=$($this.CustomProperties.$key)" }) -join [environment]::newline
	}
    
    
    [string] GetPBCTemplatePath() {
        [string] $pbcPropsFileTpl = (Join-Path ($PSScriptRoot) "PropertyBasedConfigTemplates\JVMSettings.properties")
		[string] $pbcPropsFile = Join-Path (Get-IBMTempDir) "JVMSettings-$(get-date -f yyyyMMddHHmmss)-$(Get-Random).tmp"
		$customPropString = $this.FormateToPropString()
		$tokens = @{
        	CUSTOMPROPS = $customPropString
        }
        $pbcNewSetting = Get-Content $pbcPropsFileTpl | Merge-Tokens -tokens $tokens -Verbose:$false
		Write-Verbose ("JVMSettings PBC new setting:" + $pbcNewSetting)
		$pbcNewSetting | Out-File $pbcPropsFile -encoding "ASCII"
        return $pbcPropsFile
    }
    
    [hashtable] InitializeVariableData() {
        [hashtable] $varData= @{
            "cellName" = $this.CellName
            "nodeName" = $this.NodeName
            "serverName" = $this.ServerName
            "initialHeapSize" = $this.MinHeapSize
            "maximumHeapSize" = $this.MaxHeapSize
            "verboseModeGarbageCollection" = $this.VerboseGC
            
        }
        Return $varData
    }

    <#
        Retrieves existing JVM settings
    #>
    [cIBMWebSphereJVMSettings] Get () {
        # TODO - Not needed if using Property-Based Config
        return $null
    }
}

<#
   DSC resource to add IBM WebSphere Application Profile as Node.
#>
[DscResource()]
class cIBMWebSphereNode {
    
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String] $dmgrHost
    
    [DscProperty()]
    [Int] $dmgrPort = "8879"
    
    [DscProperty(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $profileName
    
	[DscProperty(Mandatory)]
    [PSCredential] $adminCredential
    
    [DscProperty(Key)]
    [String] $nodeAgentName = "NODEAGENT"
    
    [DscProperty()]
    [String] $conntype
    
    [DscProperty()]
    [Bool] $includeapps = $true
    
    [DscProperty()]
    [Bool] $includebuses = $true
    
    [DscProperty()]
    [String] $startingport
    
    [DscProperty()]
    [Bool] $nodegroupname
    
    [DscProperty()]
    [String] $registerservice
    
    [DscProperty()]
    [PSCredential] $serviceCredential
    
    [DscProperty()]
    [String] $coregroupname
    
    [DscProperty()]
    [Bool] $noagent
    
    [DscProperty()]
    [String] $statusport
    
    [DscProperty()]
    [String] $logfile
    
    [DscProperty()]
    [PSCredential] $localUserCredential
    
    [DscProperty()]
    [String] $excludesecuritydomains
    
    [DscProperty()]
    [Bool] $asExistingNode
    
    [void] Set() {
		[Bool] $nodeAdded = New-IBMWebSphereNode `
								-dmgrHost $this.dmgrHost `
								-dmgrPort $this.dmgrPort `
								-profileName $this.profileName `
								-adminCredential $this.adminCredential `
								-nodeAgentName $this.nodeAgentName `
								-conntype $this.conntype `
								-includeapps $this.includeapps `
								-includebuses $this.includebuses `
								-startingport $this.startingport `
								-nodegroupname $this.nodegroupname `
								-registerservice $this.registerservice `
								-serviceCredential $this.serviceCredential `
								-coregroupname $this.coregroupname `
								-noagent $this.noagent `
								-statusport $this.statusport `
								-logfile $this.logfile `
								-localUserCredential $this.localUserCredential `
								-excludesecuritydomains $this.excludesecuritydomains `
								-asExistingNode $this.asExistingNode
								
		if($nodeAdded){
			Write-Verbose "Node added successfully"
		}else{
			Write-Error "Node add failed, please check the log."
		}
    }

	[bool] Test() {
		Write-Verbose "Test cIBMWebSphereNode exists"
		if(Test-IBMPSDscSequenceDebug){return $True}
		$profilePath = Get-IBMWASProfilePath $this.profileName
		if(!$profilePath -or !(Test-Path $profilePath)){
			Write-Error ("Profile not exist!: " + $this.profilePath)
		}
	
		$requireAddNode = ($this.ensure -eq [Ensure]::Present)
		$federatedProfile = Test-FederatedProfile $this.ProfileName
		
		$isDesiredState = !$requireAddNode -or $federatedProfile
		
		return $isDesiredState
	}
	
	
	
	[cIBMWebSphereNode] Get() {
		return $this
	}
    
}


<#
   DSC resource to manage IBM WebSphere Application Cluster.
#>
[DscResource()]
class cIBMWebSphereAppServerClusterMember {
	[DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Mandatory)]
	[ValidateNotNullOrEmpty()]
    [String] $DmgrProfile
    
    [DscProperty(Mandatory)]
	[ValidateNotNullOrEmpty()]
    [String] $CellName
    
    [DscProperty(Mandatory)]
	[ValidateNotNullOrEmpty()]
    [String] $ClusterName
    
    [DscProperty(Mandatory)]
	[ValidateNotNullOrEmpty()]
    [String] $NodeName
    
    [DscProperty(Key)]
    [String] $ServerName
    
    [DscProperty(Mandatory)]
	[ValidateNotNullOrEmpty()]
    [Bool] $Primary
    
    [DscProperty(Mandatory)]
    [PSCredential]  $AdminCredential

    
    
    [void] Set() {
        $create = $False
        $profilePath = Get-IBMWASProfilePath $this.DmgrProfile
        #Create Cluster or Cluster Member
        if($this.Primary){
            Write-Verbose ("Convert WebSpehre Application Server [" + $this.ServerName +"] into Cluster : " + $this.ClusterName)
            $create = New-WebSphereAppServerCluster $this.ClusterName $this.NodeName $this.ServerName $profilePath $this.AdminCredential
        }else{
            Write-Verbose ("Adding WebSpehre Application Server [" + $this.ServerName +"] into Cluster : " + $this.ClusterName)
            $create = New-WebSphereAppServerClusterMember $this.ClusterName $this.NodeName $this.ServerName $profilePath $this.AdminCredential
        }
        #Start Cluster
        Write-Verbose ("Ripple Starting the Cluster : " + $this.ClusterName)
        Start-WebSphereAppServerCluster $this.ClusterName $profilePath $this.AdminCredential -RippleStart | Out-Null
    }
    
    [bool] Test() {
    	# IF Cluster exist and Cluster Member exist return true
    	if(Test-IBMPSDscSequenceDebug){return $True}
    	$skip = $False
    	$profilePath = Get-IBMWASProfilePath $this.DmgrProfile
    	$clusterExists = Test-ClusterExists $this.ClusterName $profilePath $this.AdminCredential
        Write-Verbose ("Test if Cluster[" + $this.ClusterName +"] exists : $clusterExists")
        if($clusterExists){
            $clusterMemberExists = Test-ClusterMemberExists $this.ClusterName $this.ServerName $profilePath $this.AdminCredential
            Write-Verbose ("Test if Cluster Member[" + $this.ServerName +"] exists : $clusterMemberExists")
            if($clusterMemberExists){
                $skip = $true
                 Write-Verbose ("Cluster or Cluster Member is configured properly, skipping the DSC Set")
            }
    	}
    	return $skip
    }

	[cIBMWebSphereAppServerClusterMember] Get() {
		return $this
	}
}

<#
   DSC resource to manage WebSphere Variables settings of an IBM WebSphere Application Server.
#>
[DscResource()]
class cIBMWebSphereVariables {
    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty(Mandatory)]
    [String] $ProfileName

    [DscProperty(Key)]
    [ScopeLevel] $ScopeLevel

    [DscProperty(Key)]
    [String] $ScopeName
    
    [DscProperty()]
    [String] $ClusterName

    [DscProperty()]
    [String] $CellName

    [DscProperty()]
    [String] $ServerName
    
    [DscProperty()]
    [String] $NodeName
    
    [DscProperty(Mandatory)]
    [HashTable] $Variables
    
    [DscProperty(Mandatory)]
    [PSCredential] $WebSphereAdministratorCredential

	
	[String] FormateToPropString(){
		if(!$this.Variables){
			return $Null
		}
		
		return ($this.Variables.Keys | foreach { $key = $_;"$key=$($this.Variables.$key)" }) -join [environment]::newline
	}
	
	[String] PopulateScopeString(){
		$scopeStr = $Null
		
		if($this.ClusterName){
			$scopeStr = "Cell=$($this.CellName):ServerCluster=$($this.ClusterName)"
		}elseif ($this.NodeName){
			$scopeStr = "Cell=$($this.CellName):Node=$($this.NodeName):"
			if($this.ServerName) {
				$scopeStr += "Server=$($this.ServerName):"
			}
		}
		return $scopeStr
	}
		
	[string] GetPBCTemplatePath() {
        [string] $pbcFilePath = (Join-Path ($PSScriptRoot) "PropertyBasedConfigTemplates\WebSphereVaribles.properties")
        return $pbcFilePath
    }
	
	[string] PopulatePBCPropsFile(){
		$pbcPropsFile = Join-Path (Get-IBMTempDir) "WebSphereVaribles-$(get-date -f yyyyMMddHHmmss)-$(Get-Random).tmp"
		$scopeStr = $this.PopulateScopeString()
    	$variablesStr = $this.FormateToPropString()
    	$templateFile = $this.GetPBCTemplatePath()
        $tokens = @{
        	SCOPE = $scopeStr
        	VARIABLES = $variablesStr
        }
        $pbcNewSetting = Get-Content $templateFile | Merge-Tokens -tokens $tokens -Verbose:$false
        Write-Verbose ("PBC new setting:" + $pbcNewSetting)
        $pbcNewSetting | Out-File $pbcPropsFile -encoding "ASCII"
        
        return $pbcPropsFile;
	}
	
    [void] Set () {
    	if ($this.Ensure -eq [Ensure]::Present) {
            Write-Verbose -Message ("Applying WebSphere Variables Setting")
            $profilePath = Get-IBMWASProfilePath $this.ProfileName
            if (!$profilePath){
            	Write-Error "Invalid WebSphere Profile: $profilePath"
            }
	        $pbcPropsFile = $this.PopulatePBCPropsFile()
            Try{
				$configApplied = Set-IBMWebSpherePropertyBasedConfig `
	        		-ProfilePath $profilePath `
	                -PropertyFile $pbcPropsFile `
	                -WebSphereAdministratorCredential $this.WebSphereAdministratorCredential
		        if ($configApplied) {
		            Write-Verbose "Configuration applied successfully"
		        }
            }Finally{
	            if(Test-Path($pbcPropsFile)){
		            Remove-Item $pbcPropsFile -Force
		        }
            }
        } else {
            Write-Verbose "Removing configuration (Not Yet Implemented)"
        }
    }
    [bool] Test () {
		Write-Verbose "Checking for WebSphere Variables Settings"
		if(Test-IBMPSDscSequenceDebug){return $True}
        $profilePath = Get-IBMWASProfilePath $this.ProfileName
        $pbcPropsFile = $this.PopulatePBCPropsFile()
        $wasConfiguredCorrectly = $false
        Try{
            $wasConfiguredCorrectly = Test-IBMWebSpherePropertyBasedConfig `
        		-ProfilePath $profilePath `
                -PropertyFile $pbcPropsFile `
                -WebSphereAdministratorCredential $this.WebSphereAdministratorCredential
        }Finally{
            if(Test-Path($pbcPropsFile)){
		        Remove-Item $pbcPropsFile -Force
		    }
        }
        
        return $wasConfiguredCorrectly
    }
    [cIBMWebSphereVariables] Get () {
        # TODO - Not needed if using Property-Based Config
        return $null
    }
}


<#
   DSC resource to manage IBM WebSphere Mutual Auth SSL.
#>
[DscResource()]
class cIBMWebSphereMutualAuthSSL {
    [DscProperty(Mandatory)]
    [Ensure] $Ensure = [Ensure]::Present

	[DscProperty(Key)]
    [String] $SSLConfigName
    
	[DscProperty(Mandatory)]
    [HashTable] $DynamicSSLConfig
    
    [DscProperty(Mandatory)]
    [String] $KeyAlias
	
	[DscProperty(Mandatory)]
    [String] $KeyStoreDef
    
    [DscProperty(Mandatory)]
    [String] $TrustStoreDef
    
	[DscProperty(Mandatory)]
    [String] $CertificatesBaseDir
	
	[DscProperty(Mandatory)]
    [PSCredential] $SSLCredential
	
	[DscProperty(Mandatory)]
    [PSCredential] $WasAdminCredential
    
    [DscProperty()]
    [PSCredential] $SourcePathCredential
	
	[DscProperty(Mandatory)]
    [String] $CellName
    
    [DscProperty(Mandatory)]
    [String] $ProfileName
    
    [PSCustomObject] $KeyStore
    
    [PSCustomObject] $TrustStore

    [String] GetScope () {
    	return "(cell):$($this.CellName)"
    }
    
    [String] GetKeyStorePath ([String] $CellName, [String] $StoreName) {
    	return ('${CONFIG_ROOT}'+"/cells/$CellName/$StoreName.p12")
    }
    
	[void] Set () {
		$this.KeyStore = ConvertFrom-Json $this.KeyStoreDef
    	$this.TrustStore = ConvertFrom-Json $this.TrustStoreDef
        [String[]] $wasSSLCmds = @();
		[String] $wasAdminPwd = $this.WasAdminCredential.GetNetworkCredential().Password
		[String] $sslPwd = $this.SSLCredential.GetNetworkCredential().Password
		[String] $scope = $this.GetScope()
		# 1) Copy the Certificates to IBMTemp
		$certificatesTempDir = Join-Path (Get-IBMTempDir) "Certificates"
		Copy-RemoteItemLocal $this.CertificatesBaseDir `
							$certificatesTempDir `
							$this.SourcePathCredential -Directory
		Try{
			# 2) Create KeyStore
			$keyStoreDir = $this.KeyStorePath
			if(!$keyStoreDir){
				$keyStoreDir = $this.GetKeyStorePath($this.CellName, $this.KeyStore.Name)
			}
			$wasSSLCmds += Get-CreateKeyStoreCmd -StoreName $this.KeyStore.Name `
												 -StorePath $keyStoreDir `
												 -Scope $scope `
												 -StorePassword $wasAdminPwd
			# 3) Create TrustStore
			$trustStoreDir = $this.TrustStorePath
			if(!$trustStoreDir){
				$trustStoreDir = $this.GetKeyStorePath($this.CellName, $this.TrustStore.Name)
			}
			$wasSSLCmds += Get-CreateKeyStoreCmd -StoreName $this.TrustStore.Name `
												 -StorePath $trustStoreDir `
												 -Scope $scope `
												 -StorePassword $wasAdminPwd
												 
			$wasSSLProc = Invoke-WsAdmin `
								-ProfilePath $this.ProfileName `
								-Commands $wasSSLCmds `
								-WebSphereAdministratorCredential $this.WasAdminCredential
			if($wasSSLProc -and ($wasSSLProc.ExitCode -eq 0)){
				Write-Verbose "$($this.KeyStore.Name) and $($this.TrustStore.Name) are created successfully!"
			}else{
				Write-Error "Error occured when creating Mutual SSL Config"
			}
			$wasSSLCmds = @()
			
			# 5) Import Certificates
			$wasSSLCmds += New-ImportCertificatesCmds `
								-Store $this.KeyStore `
								-Scope $scope `
								-CertificatesDir $certificatesTempDir `
								-SSLPassword $sslPwd `
								-ProfileName $this.ProfileName `
								-WasAdminCredential $this.WasAdminCredential
										
			$wasSSLCmds += New-ImportCertificatesCmds `
								-Store $this.TrustStore `
								-Scope $scope `
								-CertificatesDir $certificatesTempDir `
								-SSLPassword $sslPwd `
								-ProfileName $this.ProfileName `
								-WasAdminCredential $this.WasAdminCredential
			
			$wasSSLProc = Invoke-WsAdmin `
								-ProfilePath $this.ProfileName `
								-Commands $wasSSLCmds `
								-WebSphereAdministratorCredential $this.WasAdminCredential
			if($wasSSLProc -and ($wasSSLProc.ExitCode -eq 0)){
				Write-Verbose "Certificates are imported successfully!"
			}else{
				Write-Error "Error occured when creating Mutual SSL Config"
			}
			$wasSSLCmds = @()
			
	        # 6) Create SSLConfig
	        $wasSSLCmds += "AdminTask.createSSLConfig('[-alias $($this.SSLConfigName) -type JSSE -scopeName $scope -keyStoreName $($this.KeyStore.Name) -keyStoreScopeName $scope -trustStoreName $($this.TrustStore.Name) -trustStoreScopeName $scope -serverKeyAlias $($this.KeyAlias) -clientKeyAlias $($this.KeyAlias) ]')"
	        
	        $wasSSLProc = Invoke-WsAdmin `
								-ProfilePath $this.ProfileName `
								-Commands $wasSSLCmds `
								-WebSphereAdministratorCredential $this.WasAdminCredential
			if($wasSSLProc -and ($wasSSLProc.ExitCode -eq 0)){
				Write-Verbose "Mutual SSL[$($this.SSLConfigName)] is configured successfully!"
			}else{
				Write-Error "Error occured when creating Mutual SSL Config"
			}
			$wasSSLCmds = @()
			# 7) Create DynamicSSLConfig
			$wasSSLCmds += "AdminTask.createDynamicSSLConfigSelection(`'[-dynSSLConfigSelectionName $($this.DynamicSSLConfig.Name) -scopeName $scope -dynSSLConfigSelectionDescription $($this.DynamicSSLConfig.Name) -dynSSLConfigSelectionInfo $($this.DynamicSSLConfig.Selection) -sslConfigName $($this.SSLConfigName) -sslConfigScope $scope -certificateAlias $($this.KeyAlias) ]`')"

		    $wasSSLProc = Invoke-WsAdmin `
								-ProfilePath $this.ProfileName `
								-Commands $wasSSLCmds `
								-WebSphereAdministratorCredential $this.WasAdminCredential
			if($wasSSLProc -and ($wasSSLProc.ExitCode -eq 0)){
				Write-Verbose "Dynamic SSL[$($this.DynamicSSLConfig.Name)] Config created successfully!"
			}else{
				Write-Error "Error occured when creating Mutual SSL Config"
			}
		} Catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        } Finally {
			# 8) Delete IBMTemp dir
			if(Test-Path($certificatesTempDir)){
	            Remove-Item $certificatesTempDir -Force -Recurse
	        }
		}

	}
	<#
    #>
    [bool] Test () {
    	$this.KeyStore = ConvertFrom-Json $this.KeyStoreDef
    	$this.TrustStore = ConvertFrom-Json $this.TrustStoreDef
    	$profilePath = Get-IBMWASProfilePath $this.ProfileName
    	$keyStorePath = Join-Path $profilePath "config/cells/$($this.CellName)/$($this.KeyStore.Name).p12"
    	if(Test-Path $keyStorePath){
            Write-Warning "KeyStore already exists, skipping config Mutual SSL"
            return $True
        }
        $trustStorePath = Join-Path $profilePath "config/cells/$($this.CellName)/$($this.TrustStore.Name).p12"
    	if(Test-Path $trustStorePath){
            Write-Warning "TrustStore already exists, skipping config Mutual SSL"
            return $True
        }
        
        return $False
    }
    <#
    #>
    [cIBMWebSphereMutualAuthSSL] Get () {
        return $this;
    }
}

<#
   DSC resource to manage IBM WebSphere PropertiesBased Configuration.
#>
[DscResource()]
class cIBMPropertiesBasedConfiguration {
    [DscProperty(Mandatory)]
    [Ensure] $Ensure = [Ensure]::Present
    [DscProperty(Key)]
    [String] $PropertiesBasedConfigFile
    [DscProperty()]
    [Hashtable] $CustomProperties = @{}
    [DscProperty(Mandatory)]
    [String] $ProfileName
    [DscProperty(Mandatory)]
    [String] $Cell
    [DscProperty()]
    [String] $Cluster
    [DscProperty()]
    [String] $Node
    [DscProperty()]
    [String] $Server
    [DscProperty()]
    [Bool] $Reboot = $False
    [DscProperty(Mandatory)]
    [PSCredential] $WebSphereAdministratorCredential
    
    <#
    #>
    [void] Set () {
    	try {
    		if ($this.Ensure -eq [Ensure]::Present) {
				$profilePath = Get-IBMWASProfilePath $this.ProfileName
				if ($profilePath) {
					$tmpPBCFile = $this.PopulatePropertiesBasedConfigFile()
					Try {
						$configApplied = Set-IBMWebSpherePropertyBasedConfig `
								-ProfilePath $profilePath `
								-PropertyFile $tmpPBCFile `
	                            -WebSphereAdministratorCredential $this.WebSphereAdministratorCredential
						Write-Verbose "IBM WebSphere PropertiesBased Configuration is Configured Successfully"
	                    if ($configApplied -and $this.Reboot) {
	                        Write-Verbose "Configuration applied successfully, restarting server"
	                    	if($this.Cluster){
	                    		Stop-WebSphereAppServerCluster $this.Cluster $profilePath $this.WebSphereAdministratorCredential
		                        Start-WebSphereAppServerCluster $this.Cluster $profilePath $this.WebSphereAdministratorCredential
	                    	} elseif ($this.Server) {
		                        Stop-WebSphereServerViaBatch $this.Server $profilePath $this.WebSphereAdministratorCredential
		                        Start-WebSphereServerViaBatch $this.Server $profilePath $this.WebSphereAdministratorCredential
	                    	}
	                    }
					} Finally {
			    		if($tmpPBCFile -and (Test-Path $tmpPBCFile)){
			    			Remove-Item $tmpPBCFile -Force
			    		}
		        	}
				} else {
                    Write-Error "Invalid WebSphere Profile: $profilePath"
                }
			} else {
	            Write-Verbose "Remove IBM WebSphere PropertiesBased Configuration (Not Yet Implemented)"
	        }
		} catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
	}
	
	[String] PopulatePropertiesBasedConfigFile () {
		$scope = New-PropertiesBasedConfigScope $this.Cell  $this.Cluster  $this.Node  $this.Server
		$environmentVariables = New-PropertiesBasedEnvironmentVariables $this.Cell  $this.Cluster  $this.Node  $this.Server
		$customrProps = Format-HashTable $this.CustomProperties
		$pbcPropsFileTpl = $this.PropertiesBasedConfigFile
		$pbcPropsFile = Join-Path (Get-IBMTempDir) "pbcConfig-$(Get-Random).tmp"
		$tokens = @{
        	SCOPE = $scope
        	ENVIRONMENTVARIABLES = $environmentVariables
        	CUSTOMPROPS = $customrProps
        }
        $pbcNewSetting = Get-Content $pbcPropsFileTpl | Merge-Tokens -tokens $tokens -Verbose:$false
		Write-Debug ("PropertiesBasedConfig:" + $pbcNewSetting)
		$pbcNewSetting | Out-File $pbcPropsFile -encoding "ASCII"
        return $pbcPropsFile
	}
	
    <#
    #>
    [bool] Test () {
    	Write-Verbose "Checking the IBM WebSphere PropertiesBased Configuration"
        if(Test-IBMPSDscSequenceDebug){return $True}
        $skipConfig = $False
        $currentConfig = $this.Get()
        if (($currentConfig.Ensure -eq $this.Ensure) -and ($currentConfig.Ensure -eq [Ensure]::Present)) {
        	$profilePath = Get-IBMWASProfilePath $this.ProfileName
        	$tmpPBCFile = $this.PopulatePropertiesBasedConfigFile()
        	Try {
				$skipConfig = Test-IBMWebSpherePropertyBasedConfig -ProfilePath $profilePath `
									                -PropertyFile $tmpPBCFile `
									                -WebSphereAdministratorCredential $this.WebSphereAdministratorCredential
        	} Finally {
	    		if($tmpPBCFile -and (Test-Path $tmpPBCFile)){
	    			Remove-Item $tmpPBCFile -Force
	    		}
        	}
        } elseif (($currentConfig.Ensure -eq $this.Ensure) -and ($currentConfig.Ensure -eq [Ensure]::Absent)) {
            $skipConfig = $true
        }
        
		if ($skipConfig) {
	    	Write-Verbose "IBM WebSphere PropertiesBased Configuration is Configured Correctly!"
	    } else {
	    	Write-Verbose "IBM WebSphere PropertiesBased Configuration is not Configured Correctly!"
	    }
    	
        return $skipConfig
    }
    
    <#
    #>
    [cIBMPropertiesBasedConfiguration] Get () {
    	$RetEnsure = [Ensure]::Absent
    	Try{
    		$RetEnsure = [Ensure]::Present
    	} Finally {
    	
    	}
    	
        $returnValue = @{
            Ensure = $RetEnsure
        }
        return $returnValue
    }
}
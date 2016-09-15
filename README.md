#cIBMWebSphereAppServer

PowerShell CmdLets and Class-Based DSC resources to manage IBM WebSphere Application Server (WAS) on Windows Environments.

To get started using this module just type the command below and the module will be downloaded from [PowerShell Gallery](https://www.powershellgallery.com/packages/cIBMWebSphereAppServer/)
```shell
PS> Install-Module -Name cIBMWebSphereAppServer
```

## Resources

* **cIBMWebSphereAppServer** installs IBM WebSphere Application Server on target machine.
* **cIBMWebSphereAppServerFixpack** applies a Websphere Fixpack on the target machine
* **cIBMWebSphereAppServerProfile** creates a WebSphere profile.
* **cIBMWebSphereJVMSettings** manages the JVM settings of a WebSphere server.
* **cIBMWebSphereAppServerClusterMember** create IBM WebSphere Application Cluster.
* **cIBMWebSphereVariables** manage WebSphere Variables settings of an IBM WebSphere Application Server.
* **cIBMWebSphereMutualAuthSSL** manage IBM WebSphere Mutual Auth SSL.
* **cIBMPropertiesBasedConfiguration** manage IBM WebSphere PropertiesBased Configuration.



### cIBMWebSphereAppServer

* **Ensure**: (Required) Ensures that WAS is Present or Absent on the machine.
* **Version**: (Key) The version of WAS to install
* **WASEdition**: (Key) The edition of WAS to install.  Options: BASE, ND, EXPRESS, DEVELOPER, LIBERTY
* **InstallationDirectory**: Installation path.  Default: C:\IBM\WebSphere\AppServer.
* **PlusJava7**: _Boolean_ Determines whether or not the IBM Java 7 SDK gets installed
* **IMSharedLocation**: Location of the IBM Installation Manager cache.  Default: C:\IBM\IMShared
* **InstallMediaConfig**: (Optional) Path to the clixml export of the IBMProductMedia object that contains media configuration.
* **ResponseFileTemplate**: (Optional) Path to the response file template to use for the installation.
* **SourcePath**: UNC or local file path to the directory where the IBM installation media resides.
* **SourcePathCredential**: (Optional) Credential to be used to map sourcepath if a remote share is being specified.

_Note_ InstallMediaConfig and ResponseFileTemplate are useful parameters when there's no built-in support for the WAS edition you need to install or when you have special requirements based on how your media is setup or maybe you have unique response file template needs.
If you create your own Response File template it is expected that the template has the variables: **sharedLocation** and **wasInstallLocation**.  See sample response file template before when planning to roll out your own.

### cIBMWebSphereAppServerFixpack

* **Ensure**: (Required) Ensures that WAS fixpack is Present or Absent on the machine.
* **Version**: (Key) The version of WAS fixpack to install
* **WASEdition**: (Key) The edition of WAS.  Options: BASE, ND, EXPRESS, DEVELOPER, LIBERTY
* **WebSphereInstallationDirectory**: Directory where AppServer is installed.  Default: C:\IBM\WebSphere\AppServer.
* **SourcePath**: _array_ UNC or local file path to the fixpack zip-files.  Supports multiple file paths.
* **SourcePathCredential**: (Optional) Credential to be used to map sourcepath if a remote share is being specified.

### cIBMWebSphereAppServerProfile

* **Ensure**: (Required) Ensures that WAS profile is Present or Absent on the machine.
* **ProfileName**: (Key) The name of the profile
* **ProfilePath**: (Optional) Location of profile.  If not specified it'll be added to the AppServer\profiles directory.
* **NodeName**: (Required) Name of the WebSphere Node for the server
* **CellName**: (Optional) Should only be used for Dmgr.
* **HostName**: FQDN of the host in the target machine.
* **TemplatePath**: (Optional) full path to the template to be used for creating this profile
* **AdminCredential**: (Optional) Credential to be used to create the profiles (if applicable)
* **EnableSecurity**: Determines whether or not the profile should have security enable.  Default is true
* **ServerName**: The name of the application server if the profile type is not Management or Dmgr
* **ProfileType**: The type of profile (maps to profiles withing the profileTemplates directory)
* **DmgrHost**: If not management profile, the hostname of the Dmgr
* **DmgrPort**: If not management profile, the SOAP port of the Dmgr.  Default: 8879

### cIBMWebSphereJVMSettings
* **Ensure**: (Required) Ensures that WAS profile is Present or Absent on the machine.
* **ProfileName**: (Required) The name of the profile
* **NodeName**: (Required) The name of the WebSphere Node that the server belongs to
* **CellName**: (Required) The name of the WebSphere Cell that the server belongs to
* **ServerName**: (Key) The name of the application server
* **MinHeapSize**: The minimum JVM heap size in MB. Default 1024MB
* **MaxHeapSize**: The maximum JVM heap size in MB. Default 2048MB
* **VerboseGC**: Enable verbose garbage collection (useful to help monitor memory usage)
* **WebSphereAdministratorCredential**: (Required) Credential to be used to apply changes


### cIBMWebSphereAppServerClusterMember
* **Ensure**: (Required) Ensures that WAS Cluster Member is Present or Absent on the machine.
* **DmgrProfile**: (Required) The name of the dmgr profile
* **CellName**: (Required) The name of the WebSphere Cell that the server belongs to
* **ClusterName**: (Required) The name of the WebSphere Cluster that the server belongs to
* **NodeName**: (Required) The name of the WebSphere Node that the server belongs to
* **ServerName**: (Key) The name of the application server
* **Primary**: (Required) Boolean flag for whether the server is primary amount it's cluster  
* **AdminCredential**: (Required) WebSphere Admin Credential to be used to apply changes

### cIBMWebSphereVariables
* **Ensure**: (Required) Ensures that WebSphere Variables is Present or Absent on the machine.
* **ProfileName**: (Required) The name of the profile
* **ScopeLevel**: (Key) ScopeLevel of WebSphere Variables, available options are Cell, Node, Server, Cluster
* **ScopeName**: (Required) The name of the WebSphere Cluster that the server belongs to
* **CellName**: The name of the WebSphere Cell for applying the WebSphere Variables
* **ClusterName**: The name of the WebSphere Cluster for applying the WebSphere Variables
* **NodeName**: The name of the WebSphere Node for applying the WebSphere Variables
* **ServerName**: The name of the application server for applying the WebSphere Variables
* **Variables**: (Required) HashTable of Websphere server variables
* **WebSphereAdministratorCredential**: (Required) WebSphere Admin Credential to be used to apply changes


### cIBMWebSphereMutualAuthSSL
* **Ensure**: (Required) Ensures that WAS profile is Present or Absent on the machine.
* **SSLConfigName**: (Key) The name of Mutual SSL Config
* **DynamicSSLConfig**: (Required) The name of Dynamic SSL
* **KeyAlias**: (Required) The Alias of the personal key
* **KeyStoreDef**: (Required) The description of the KeyStore and it's certificates in JSON format
* **TrustStoreDef**: (Required) The description of the TrustStore and it's certificates in JSON format
* **CertificatesBaseDir**: (Required) The directory which contains the certificates
* **SSLCredential**: (Required) Personal SSL Credentials
* **WasAdminCredential**: (Required) WebSphere Admin Credential to be used to apply changes
* **SourcePathCredential**: (Optional) Credential to be used to map sourcepath if a remote share is being specified.
* **CellName**: (Required) The name of the WebSphere Cell for creating Mutual Auth SSL
* **ProfileName**: (Required) The name of the dmgr profile

### cIBMPropertiesBasedConfiguration
* **Ensure**: (Required) Ensures that WAS profile is Present or Absent on the machine.
* **PropertiesBasedConfigFile**: (Key) PropertiesBased config file path.
* **CustomProperties**: (Optional) Customer Properties for PropertiesBased config file
* **ProfileName**: (Required) The name of the websphere profile
* **CellName**: (Required) The name of the WebSphere Cell for applying the PropertiesBased config
* **ClusterName**: (Optional) The name of the WebSphere Cluster for applying the PropertiesBased config
* **NodeName**: (Optional) The name of the WebSphere Node for applying the PropertiesBased config
* **ServerName**: (Optional) The name of the application server for applying the PropertiesBased config
* **Reboot**: (Optional) Boolean flag for reboot the cluster/server, default is False 
* **WebSphereAdministratorCredential**: (Required) WebSphere Admin Credential to be used to apply changes





## Depedencies
* [cIBMInstallationManager](http://github.com/cBlueShell/cIBMInstallationManager) DSC Resource/CmdLets for IBM Installation Manager
* [7-Zip](http://www.7-zip.org/ "7-Zip") needs to be installed on the target machine.  You can add 7-Zip to your DSC configuration by using the Package
DSC Resource or by leveraging the [x7Zip DSC Module](https://www.powershellgallery.com/packages/x7Zip/ "x7Zip at PowerShell Gallery")

## Versions

### 1.1.0
* New DSC Resources for 
	* managing JVM settings **cIBMWebSphereJVMSettings**
	* managing IBM WebSphere Application Cluster **cIBMWebSphereAppServerClusterMember**
	* managing WebSphere Variables settings of an IBM WebSphere Application Server **cIBMWebSphereVariables**
	* managing IBM WebSphere Mutual Auth SSL **cIBMWebSphereMutualAuthSSL**
	* managing IBM WebSphere PropertiesBased Configuration **cIBMPropertiesBasedConfiguration**
	
* Fixes various bugs in profile managment and property-based config cmdlets

### 1.0.5
* Minor fixes
* New CmdLets: **Start-WebSphereServer**, **Stop-WebSphereServer**, **Stop-AllWebSphereServers**, **Start-WebSphereNodeAgent**, **Stop-WebSphereNodeAgent**, **Test-WebSphereServerService**, **Test-WebSphereServerServiceExists**

### 1.0.4
* IBM Java 7 installation support via new DSC property _PlusJava7_

### 1.0.3
* New DSC Resource for creating WebSphere profiles (including Dmgr support) **cIBMWebSphereAppServerProfile**
* New CmdLets: **New-IBMWebSphereProfile**, **Invoke-ManageProfiles**, **Start-WebSphereDmgr**, **Stop-WebSphereDmgr**

### 1.0.2
* New DSC Resource for installing fixpacks **cIBMWebSphereAppServerFixpack**
* Adds wsadmin cmdlets (includes IBM's [wsadminlib.py](https://github.com/wsadminlib/wsadminlib) which can be added as a module dependency to wsadmin jython scripts)
* Adds Property-Based Config cmdlets
* Depends on cIBMInstallationManager v1.0.4 or above
* New CmdLets: **Install-IBMWebSphereAppServerFixpack**, **Invoke-WsAdmin**, **Set-WsAdminTempDir**, **Get-WsAdminTempDir**, **Import-IBMWebSpherePropertyBasedConfig**, **Export-IBMWebSpherePropertyBasedConfig**, **Test-IBMWebSpherePropertyBasedConfig**, **Get-IBMWebSpherePropertyBasedConfig**

### 1.0.1
* Adds topology cmdlets and cmdlet to create windows services for WAS servers
    
### 1.0.0
* Initial release with the following resources 
    - cIBMWebSphereAppServer

## Testing

The table below outlines the tests that various WAS editions/versions have been verify to date.  As more configurations are tested there should be a corresponding entry for Media Configs and Response File Templates.  Could use help on this, pull requests welcome :-)

| WAS Version | Operating System               | BASE | ND | EXPRESS | DEVELOPER | LIBERTY |
|-------------|--------------------------------|------|----|---------|-----------|---------|
| v8.5.5      |                                |      |    |         |           |         |
|             | Windows 2012 R2 (64bit)        |      |  x |         |           |         |
|             | Windows 10 (64bit)             |      |  x |         |           |         |
|             | Windows 2008 R2 Server (64bit) |      |    |         |           |         |


## Media Files

The installation depents on media files that have already been downloaded.  In order to get the media files please check your IBM Passport Advantage site.

The table below shows the currently supported (i.e. tested) media files.

| WAS Version | WAS Edition | Media Files           |
|-------------|-------------|-----------------------|
| v8.5.5      |             |                       |
|             | ND          | WASND_v8.5.5_1of3.zip |
|             |             | WASND_v8.5.5_2of3.zip |
|             |             | WASND_v8.5.5_3of3.zip |

## Examples

### Install WAS Network Deployment Edition

This configuration will install [7-Zip](http://www.7-zip.org/ "7-Zip") using the DSC Package Resource, install/update IBM Installation Manager
and finally install IBM WebSphere Application Server Network Deployment edition

Note: This requires the following DSC modules:
* xPsDesiredStateConfiguration
* cIBMInstallationManager

```powershell
Configuration WASND
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DSCResource -ModuleName 'cIBMInstallationManager' -ModuleVersion '1.0.7'
    Import-DSCResource -ModuleName 'cIBMWebSphereAppServer' -ModuleVersion '1.1.0'
    Package SevenZip {
        Ensure = 'Present'
        Name = '7-Zip 9.20 (x64 edition)'
        ProductId = '23170F69-40C1-2702-0920-000001000000'
        Path = 'C:\Media\7z920-x64.msi'
    }
    cIBMInstallationManager IIMInstall
    {
        Ensure = 'Present'
        InstallationDirectory = 'C:\IBM\IIM'
        Version = '1.8.3'
        SourcePath = 'C:\Media\agent.installer.win32.win32.x86_64_1.8.4001.20160217_1716.zip'
        DependsOn= '[Package]SevenZip'
    }
    cIBMWebSphereAppServer WASNDInstall
    {
        Ensure = 'Present'
        WASEdition = 'ND'
        InstallationDirectory = 'C:\IBM\WebSphere\AppServer'
        Version = '8.5.5'
        SourcePath = 'C:\Media\WASND855\'
        DependsOn= '[cIBMInstallationManager]IIMInstall'
    }
    cIBMWebSphereAppServerFixpack WASFixpackInstall
    {
        Ensure = 'Present'
        WASEdition = 'ND'
        WebSphereInstallationDirectory = 'C:\IBM\WebSphere\AppServer'
        Version = '8.5.5.6'
        SourcePath = @('C:\Media\WAS855_FP\8.5.5-WS-WAS-FP0000006-part1.zip', 'C:\Media\WAS855_FP\8.5.5-WS-WAS-FP0000006-part2.zip')
        DependsOn= '[cIBMWebSphereAppServer]WASNDInstall'
    }
    cIBMWebSphereAppServerClusterMember WASClusterMember
	{
		Ensure = 'Present'
		DmgrProfile = 'dmgr'
		CellName = 'wasCell01'
		ClusterName = 'wasCluster'
		NodeName = 'wasNode01'
		ServerName = 'wasServer01'
		Primary = $True
		AdminCredential = $wasAdminCredental
	}
    cIBMWebSphereVariables WASVaribles
	{
		Ensure = 'Present'
		ScopeLevel = 'Cluster'
		ScopeName = wasCluster'
		CellName = 'wasCluster'
		ClusterName = wasCluster'
		Variables = @{
			DB2UNIVERSAL_JDBC_DRIVER_PATH='D:/ibm/jdbc/db2'
			UNIVERSAL_JDBC_DRIVER_PATH='D:/ibm/jdbc/db2'
		}
		ProfileName = 'dmgr'
		WebSphereAdministratorCredential = $wasAdminCredental
	}
	cIBMWebSphereMutualAuthSSL WASMutualSSL
	{
		Ensure = 'Present'
		DynamicSSLConfig = @{
						Name = "WebServiceOutbound"
						Selection = "*,ws.acme.com,*|*,rest.acme.com,*"
					}
		SSLConfigName = 'WebServiceMutualSSLConfig'
		KeyAlias = 'AcmeServices'
		KeyStoreDef = '{
				"Name" : "AcmeKeyStore",
				"PersonalCertificates" : [
					{
						"Alias" : "AcmeServices",
						"FilePath" : "acme-srvs.pfx"
					}
				],
				"SignerCertificates" : [
					{
						"Alias" : "acmeissuing",
						"FilePath" : "acmeissuing.cer"
					}
				]
			}'
		TrustStoreDef = '{
				"Name" : "AcmeTrustStore",
				"SignerCertificates" : [
					{
						"Alias" : "GeoTrust_Root",
						"FilePath" : "GeoTrust_Root.cer"
					}
				]
			}'
		CertificatesBaseDir = '\\nas1.acme.com\media\certificates'
		SourcePathCredential = $MediaCredential
		SSLCredential = $SSLCertCredential
		WasAdminCredential = $WasAdminCredental
		CellName = 'WasCell'
		ProfileName = 'dmgr'
	}
	cIBMPropertiesBasedConfiguration WasPropertiesBasedConfig
	{
		Ensure = 'Present'
		ProfileName = 'dmgr'
		Cell = 'wasCell'
		Node = 'wasNode01'
		Server = 'wasServer01'
		PropertiesBasedConfigFile = 'Resources\PropertiesBasedConfiguration\FebSessionTimeout.props'
		WebSphereAdministratorCredential = $WasAdminCredental
	}
}
WASND
Start-DscConfiguration -Wait -Force -Verbose WASND
```
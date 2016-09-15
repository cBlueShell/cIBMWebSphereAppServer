Configuration WASND
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DSCResource -ModuleName 'cIBMInstallationManager'
    Import-DSCResource -ModuleName 'cIBMWebSphereAppServer'
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
        SourcePath = 'C:\Media\agent.installer.win32.win32.x86_1.8.3000.20150606_0047.zip'
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
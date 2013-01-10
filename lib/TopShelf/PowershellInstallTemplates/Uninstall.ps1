function UninstallService 
{
param(	
	$serviceName,
	$instance,
	[string]$File = $(throw "file is a required parameter.")
)
	
	[xml]$installXml = Get-Content $File

	$serviceName 	= $installXml.InstallService.serviceName
	$instance 	 	= $installXml.InstallService.instance

	Get-ChildItem "*.exe" | ForEach-Object {
		& "$_" uninstall 
	}
	return $serviceName
}

function IIF([string]$Param, [string]$xmlValue){
	if($Param) { $Param }
	else { $XmlValue }
}

function RunInstaller($arguments)
{
	$environment = "Build"
	
	if ($arguments){ $environment = $arguments } 
	
	$srvName = UninstallService -File .\$environment.xml.Configuration.xml
}

RunInstaller $args

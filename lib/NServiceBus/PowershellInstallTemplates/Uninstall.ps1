function UninstallService 
{
param(	
	$serviceName,
	$instance,
	[string]$File = $(throw "file is a required parameter.")
)
	
	[xml]$installXml = Get-Content $File

	$serviceName 	= $installXml.Configuration.serviceName
	$instance 	 	= $installXml.Configuration.instance

	& ".\nservicebus.host.exe" /uninstall /serviceName:"$serviceName" /instance:"$instance"
	return $serviceName + "$" + $instance
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

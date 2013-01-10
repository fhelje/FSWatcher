function IIF([string]$Param, [string]$xmlValue){
	if($Param) { $Param }
	else { $XmlValue }
}

function RunInstaller($arguments)
{
	$environment = "Build"
	
	if ($arguments){ $environment = $arguments } 

	Write-Host "Nothing to uninstall."	
}

RunInstaller $args

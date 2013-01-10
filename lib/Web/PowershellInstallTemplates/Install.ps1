function IIF([string]$Param, [string]$xmlValue){
	if($Param) { $Param }
	else { $XmlValue }
}

$environment = "Build"

if ($args){  
	$environment = $args
	$file = "{0}.xml.WebInstall.xml" -f $environment
	Write-Host $file
	[xml]$installXml = Get-Content .\$file

	$website            = $installXml.InstallWeb.website
	$webapplication 	= $installXml.InstallWeb.webapplication
	$applicationpool 	= $installXml.InstallWeb.applicationpool
	$framework 	        = $installXml.InstallWeb.framework

	$usr = IIF -Param $username -XmlValue $installXml.InstallWeb.webapplicationuser
	$pwd = IIF -Param $password -XmlValue $installXml.InstallWeb.webapplicationpassword
	
	$envSetParameters = "{0}.xml.SetParameters.xml" -f $environment 
	
	rm .\Stralfors.NHSBT.Api.Web.SetParameters.xml
	
	cp $envSetParameters Stralfors.NHSBT.Api.Web.SetParameters.xml -Force 
	
	.\Stralfors.NHSBT.Api.Web.deploy.cmd /Y | out-null
	Write-Host "Run script with variables -AppPoolName $applicationpool -UserName $usr -Password $pwd -FrameworkVersion $framework" -Foreground Magenta
	.\CreateAppPool.ps1 -AppPoolName "$applicationpool" -UserName "$usr" -Password "$pwd" -FrameworkVersion "$framework"
	.\AssignAppPoolToWebSite.ps1 -AppPoolName "$applicationpool" -WebSite "$website\$webapplication" 
}
else
{
	Write-Host "You have to tell wht environment to install for!"
}
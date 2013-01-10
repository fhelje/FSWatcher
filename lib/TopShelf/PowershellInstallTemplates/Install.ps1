function IIF([string]$Param, [string]$xmlValue){
	if($Param) { $Param }
	else { $XmlValue }
}

function replaceTokens{
param(
	$environmentFile,
	$sourceFile,
	$destinationFile
)
	$b = [string]::join([environment]::newline, (get-content -path $sourceFile))
	$lookupTable = @{ }
	Write-Host $environmentFile
	[xml]$xml = Get-Content $environmentFile

	$xml.Configuration.InstallService.get_ChildNodes() | ForEach-Object {
		$lookupTable.Add("@@{0}@@" -f $_.get_Name(), $_.get_InnerText())
	} 

	$lookupTable.GetEnumerator() | ForEach-Object { 
		$b = $b -replace $_.Key, $_.Value 
	}
	$b | Set-Content -Path $destinationFile
}
$environment = "Build"

if ($args){  
	$environment = $args
	$file = "{0}.xml.Configuration.xml" -f $environment
	[xml]$installXml = Get-Content .\$file

	$serviceName 	= $installXml.Configuration.InstallService.serviceName

	$usr = IIF -Param $username -XmlValue $installXml.Configuration.InstallService.username
	$pwd = IIF -Param $password -XmlValue $installXml.Configuration.InstallService.password
	# replace values in config file
	
	Get-ChildItem .\*.* -Include *.dll.config, *.exe.config, log4net.config | ForEach-Object {
		if (Test-Path $_){
			replaceTokens -environmentFile .\$file -sourceFile $_ -destinationFile $_
		}
	}
	
	Get-ChildItem "*.exe" | ForEach-Object {
		Write-Host "$_"
		& "$_" install /username:"$usr" /password:"$pwd" 
	}
	#$retval = """" + "$serviceName" + "$" + "$instance" + """"
	$retval = "$serviceName"
	Write-Host $retval
	Start-Service $retval
}
else
{
	Write-Host "You have to tell what environment to install for!" -foregroundcolor "red"
}
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

	[xml]$xml = Get-Content $environmentFile

	$xml.Configuration.get_ChildNodes() | ForEach-Object {
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

	Get-ChildItem "*.config" | ForEach-Object {
		if (Test-Path $_){
			replaceTokens -environmentFile .\$file -sourceFile $_ -destinationFile $_
		}
	}
}
else
{
	Write-Host "You have to tell wht environment to install for!"
}
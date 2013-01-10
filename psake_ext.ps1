function Get-File-Exists-On-Path
{
    param(
        [string]$file
    )
    $results = ($Env:Path).Split(";") | Get-ChildItem -filter $file -erroraction silentlycontinue
    $found = ($results -ne $null)
    return $found
}

function Get-Git-Commit
{
    if ((Get-File-Exists-On-Path "git.exe")){
        $gitLog = git log --oneline -1
        return $gitLog.Split(' ')[0]
    }
    else {
        return "0000000"
    }
}

function Get-Hg-Commit
{
    if ((Get-File-Exists-On-Path "hg.exe")){
        $hgRev = hg tip --template "{rev}"
        return $hgRev
    }
    else {
        return "0000000"
    }
}

function Generate-Assembly-Info
{
param(
    [string]$clsCompliant = "true",
    [string]$title, 
    [string]$description, 
    [string]$company, 
    [string]$product, 
    [string]$copyright, 
    [string]$version,
    [string]$fileVersion,
    [string]$file = $(throw "file is a required parameter.")
)
     
  $asmInfo = "using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

#if !SILVERLIGHT
[assembly: SuppressIldasmAttribute()]
#endif
[assembly: CLSCompliantAttribute($clsCompliant )]
[assembly: ComVisibleAttribute(false)]
[assembly: AssemblyTitleAttribute(""$title"")]
[assembly: AssemblyDescriptionAttribute(""$description"")]
[assembly: AssemblyCompanyAttribute(""$company"")]
[assembly: AssemblyProductAttribute(""$product"")]
[assembly: AssemblyCopyrightAttribute(""$copyright"")]
[assembly: AssemblyVersionAttribute(""$version"")]
[assembly: AssemblyInformationalVersionAttribute(""$version"")]
[assembly: AssemblyFileVersionAttribute(""$fileVersion"")]
[assembly: AssemblyDelaySignAttribute(false)]
"

    $dir = [System.IO.Path]::GetDirectoryName($file)
    if ([System.IO.Directory]::Exists($dir) -eq $false)
    {
        if($verbose) { Write-Host "Creating directory $dir" }
        [System.IO.Directory]::CreateDirectory($dir)
    }
    if($verbose) { Write-Host "Generating assembly info file: $file" }
    Write-Output $asmInfo > $file
}

# Properties för RoundHousE
function Generate-Build-Info
{
param(
    [string]$file = $(throw "file is a required parameter.")
)
  if(Test-Path $file)
  {
    [xml]$buildInfoData  = get-content $file
    $commit = Get-Hg-Commit
    $majorVersion = $buildInfoData.buildInfo.versionMajor;
    $minorVersion = $buildInfoData.buildInfo.versionMinor;
    $revisionVersion = $buildInfoData.buildInfo.versionPatch;
    $platform = "Any CPU"
    $configuration = "Release"
    $framework = "net-4.0"
    
    $buildInfo = "<buildInfo>
  <projectName>DistributionReportService</projectName>
  <companyName>Strålfors AB</companyName>
  <versionMajor>$majorVersion</versionMajor>
  <versionMinor>$minorVersion</versionMinor>
  <versionPatch>$revisionVersion</versionPatch>
  <buildNumber>$commit</buildNumber>
  <revision>$commit</revision>
  <version>$majorVersion.$minorVersion.$revisionVersion.$commit</version>
  <repositoryPath>$repositoryPath</repositoryPath>
  <microsoftNetFramework>@framework</microsoftNetFramework>
  <msbuildConfiguration>$configuration</msbuildConfiguration>
  <msbuildPlatform>$platform</msbuildPlatform>
  <builtWith>psake</builtWith>
</buildInfo>"
    $dir = [System.IO.Path]::GetDirectoryName($file)
    if ([System.IO.Directory]::Exists($dir) -eq $false)
    {
        if($verbose) { Write-Host "Creating directory $dir" }
        [System.IO.Directory]::CreateDirectory($dir)
    }
    if($verbose) { Write-Host "Generating buildinfo info file: $file" }
    Write-Output $buildInfo > $dir\_buildInfo.xml	
  }
  else
  {
    Write-Host "WARNING: You are missing the buildinfo.xml for database project." -ForegroundColor Magenta
  }
}
$roundHousEDirectories = @(
                    "functions",
                    "permissions",
                    "runAfterOtherAnyTimeScript",
                    "sprocs",
                    "up",
                    "views"
                );

function MakeRoundHousEDirectories
{
param(
    $outputRoot,
    $prjName
)
    
    mkdir $outputRoot\$prjName | out-null
    foreach($rhDir in $roundHousEDirectories) {
        mkdir $outputRoot\$prjName\$rhDir | out-null
    }		
}

function CopyDatabaseFiles
{
param(
$projectDirectory,
$outputDirectory
)
    
    cp -Path $projectDirectory\*.xml -Destination $outputDirectory\. | out-null
    foreach($rhDir in $roundHousEDirectories) {
        cp -Path $projectDirectory\$rhDir\*.sql -Destination $outputDirectory\$rhDir\. -Recurse  | out-null
    }		
}

function InsertVersionAttributeInEnvironmentSqlFiles
{
	param ($sqlEnvironmentFilesDirectory,$tokensToReplace,$replacementValue)

	
	$temp = Get-ChildItem $sqlEnvironmentFilesDirectory\*.sql | Select-Object Fullname
 	foreach($file in $temp)
	 {
		if($file.Fullname -eq $null) { break }
		if(Test-Path $file.Fullname) {
			(Get-Content $file.Fullname) | ForEach-Object{ $_ -replace $tokensToReplace, $replacementValue } | Set-Content $file.Fullname 
		}
	 }
	
}


function Generate-RoundHousE-Cmd
{
param(
    $databaseName,
    $sqlFilesDirectory,
    $serverDatabase,
    $repositoryPath,
    $versionFile = "_buildInfo.xml",
    $versionXpath = "//buildInfo/version",
    $environment,
    [string]$file = $(throw "file is a required parameter.")
)
    $roundhousebat = "@echo off

SET database.name=""$databaseName""
SET sql.files.directory=""$sqlFilesDirectory""
SET server.database=""$serverDatabase""
SET repository.path=""$repositoryPath""
SET version.file=""$sqlFilesDirectory\$versionFile""
SET version.xpath=""$versionXpath""
SET environment=""$environment""

rh.exe /d=%database.name% /f=%sql.files.directory% /s=%server.database% /vf=%version.file% /vx=%version.xpath% /r=%repository.path% /env=%environment% /simple --noninteractive
"
    Write-ToFile -data $roundhousebat -file $file
}

function Generate-RoundHousE-Drop-Cmd
{
param(
    $databaseName,
    $sqlFilesDirectory,
    $serverDatabase,
    $repositoryPath,
    $versionFile = "_buildInfo.xml",
    $versionXpath = "//buildInfo/version",
    $environment,
    [string]$file = $(throw "file is a required parameter.")
)
    $roundhousebat = "@echo off

SET database.name=""$databaseName""
SET sql.files.directory=""$sqlFilesDirectory""
SET server.database=""$serverDatabase""
SET repository.path=""$repositoryPath""
SET version.file=""$sqlFilesDirectory\$versionFile""
SET version.xpath=""$versionXpath""
SET environment=""$environment""

rh.exe /d=%database.name% /f=%sql.files.directory% /s=%server.database% /vf=%version.file% /vx=%version.xpath% /r=%repository.path% /env=%environment% /drop --noninteractive
"
    Write-ToFile -data $roundhousebat -file $file
}

function Run-RoundHousE
{
param(
    $databaseName,
    $sqlFilesDirectory,
    $serverDatabase,
    $repositoryPath,
    $versionFile,
    $versionXpath,
    $environment,
    $rhCatalog
)
    $old = pwd
    cd $build_dir
    cd $rhCatalog
    exec { &".\rh.exe" /d=$databaseName /f=$sqlFilesDirectory /s=$serverDatabase /vf=$versionFile /vx=$versionXpath /r=$repositoryPath /env=$environment /simple --noninteractive }
    cd $old
}

function GetDbName {
    param (
        [string]$solution 
    )
    $parts = $solution.Split(".")
    return $parts[$parts.length-2]
}

function Write-ToFile{
    param(
        $data,
        [string]$file = $(throw "file is a required parameter.")
    )

    $dir = [System.IO.Path]::GetDirectoryName($file)
    if ([System.IO.Directory]::Exists($dir) -eq $false)
    {
        if($verbose) { Write-Host "Creating directory $dir" }
        [System.IO.Directory]::CreateDirectory($dir)
    }
    if($verbose) { Write-Host "Generating buildinfo info file: $file" }
    Write-Output $data | out-file $file -encoding ASCII
}
function Get-VSSolution-ProjectsName {
param (
    [parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]
    $Path
)

$returnvalue = @()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Path = ($Path | Resolve-Path).ProviderPath

$SolutionRoot = $Path | Split-Path

$SolutionProjectPattern = @"
(?x)
^ Project \( " \{ FAE04EC0-301F-11D3-BF4B-00C04F79EFBC \} " \)
\s* = \s*
" (?<name> [^"]* ) " , \s+
" (?<path> [^"]* ) " , \s+
"@

Get-Content -Path $Path |
    ForEach-Object {
        if ($_ -match $SolutionProjectPattern) {
            $name  = $Matches['name']
            $returnvalue += $name
        }
    }	
    return $returnvalue
}
function Get-VSSolution-ProjectsFile {
param (
    [parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]
    $Path
)

$returnvalue = @()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Path = ($Path | Resolve-Path).ProviderPath

$SolutionRoot = $Path | Split-Path

$SolutionProjectPattern = @"
(?x)
^ Project \( " \{ FAE04EC0-301F-11D3-BF4B-00C04F79EFBC \} " \)
\s* = \s*
" (?<name> [^"]* ) " , \s+
" (?<path> [^"]* ) " , \s+
"@

Get-Content -Path $Path |
    ForEach-Object {
        if ($_ -match $SolutionProjectPattern) {
            $ProjectPath = $SolutionRoot | Join-Path -ChildPath $Matches['path']
            $ProjectPath = ($ProjectPath | Resolve-Path).ProviderPath
            $ProjectRoot = $ProjectPath | Split-Path
            
            $returnvalue.Add($ProjectPath)
        }
    }	
    return $returnvalue
}
function Get-VSSolution-TestProjects {
param (
    $Path
)
    $Projects = Get-VSSolution-ProjectsName $Path 
    return $Projects -like "*.[Tt]est"
}
function Get-VSSolution-WebProjects {
param (
    $Path
)
    $Projects = Get-VSSolution-ProjectsName $Path 
    return $Projects -like "*.[Ww]eb"
}
function Get-VSSolution-TestProjectDlls {
param (
    $Path
)
    $projects = Get-VSSolution-TestProjects $Path
    $retval = @()
    foreach($prj in $projects){
        $retval += $prj + ".dll"
    }
    return $retval
}
function Get-VSSolution-WebProjectDlls {
param (
    $Path
)
    $projects = Get-VSSolution-WebProjects $Path
    $retval = @()
    foreach($prj in $projects){
        $retval += $prj + ".dll"
    }
    return $retval
}
function Get-VSSolution-AcceptansTestProjects {
param (
    $Path
)
    $Projects = Get-VSSolution-ProjectsName $Path 
    return $Projects -like "*.[Aa]cceptans[Tt]est"
}
function Get-VSSolution-AcceptansTestProjectDlls {
param (
    $Path
)
    $projects = (Get-VSSolution-AcceptansTestProjects $Path) 
    $retval = @()
    foreach($prj in $projects){
        $retval += $prj + ".dll"
    }
    return $retval
}
function Get-VSSolution-DatabaseProjects {
param (
    $Path
)
    $Projects = Get-VSSolution-ProjectsName $Path 
    return $Projects -like "*.[Dd]atabase"
}
function Get-VSSolution-MessagesProjects {
param (
    $Path
)
    $Projects = Get-VSSolution-ProjectsName $Path 
    return $Projects -like "*.[Mm]essages"
}
function Get-VSSolution-AdapterRuntimeProjects {
param (
    $Path
)
    $Projects = Get-VSSolution-ProjectsName $Path 
    return $Projects -like "*.[Rr]untime"
}
function CreateSchemas{
    param(
        $build_dir,
        $output
    )
    $xsdPath = "$env:ProgramFiles\Microsoft SDKs\Windows\v7.0A\bin\NETFX 4.0 Tools"
    $files = Get-ChildItem $build_dir\*.Messages.dll 
    foreach($file in $files){
        $namespace = $file.Name -replace ".dll" 
        
        $types = Read-MessageTypes -File $file.Fullname
        foreach($type in $types){
            $outfile = $namespace + "." + $type 
            mkdir "$output\Schemas\$outfile" | out-null
            exec { &"$xsdPath\xsd.exe" $file /type:$type /out:"$output\Schemas\$outfile" /nologo}
            
        }
    }
}
$xpathHash = @{ 
    "database" = "environment/database"; 
    "services" = "environment/services"; 
    "web" = "/environment/web[@name = '{0}']"; 
    "EIF" = "environment/EIF[@name = '{0}']"; 
    "app" = "environment/application[@name = '{0}']"; 
    "selfhost" = "environment/selfhost[@name = '{0}']"; 
}

$logicalNameReplace = @{
    ".Runtime" = "";
    ".AcceptansTest" = "";
}
function GetLogicalProjectName([string]$name) {

    $nameArr = $name.Split('.') 
    $programType = ".{0}" -f $nameArr[$nameArr.Length-1]
    if($programType -and $logicalNameReplace.ContainsKey($programType)){
        $value = $logicalNameReplace.Get_Item($programType)
        return $name -replace $programType, $value
    }
    else {
        return $name
    }
}



function replaceTokensInTextFile{
param($sourceFile,$tokensToReplace,$replacementValue)

$contents = get-content $sourceFile -readcount 0
$replace = $contents[0].Replace($tokensToReplace,$replacementValue)

Set-Content -$replace -Path $sourceFile 
}


function replaceTokens{
param(
    $environmentFile,
    $sourceFile,
    $destinationFile,
    $adaptername	
)
    $b = [string]::join([environment]::newline, (get-content -path $sourceFile))
    $lookupTable = @{ }
    [xml]$xml = Get-Content $environmentFile
    $logicalName = GetLogicalProjectName($adaptername)
    foreach($hash in $xpathHash.GetEnumerator()){
        $xpath = $hash.Value -f $logicalName
        $xml.SelectNodes($xpath) | ForEach-Object {$_.get_ChildNodes() } | ForEach-Object {
            $lookupTable.Add("@@{0}@@" -f $_.get_Name(), $_.InnerText)
        } 
    }

    $lookupTable.GetEnumerator() | ForEach-Object { 
        $b = $b -replace $_.Key, $_.Value 
    }
    $b | Set-Content -Path $destinationFile
}

function replaceTokensEif {
param(
    $environmentFile,
    $sourceFile,
    $destinationFile,
    $adaptername
)
    $b = [string]::join([environment]::newline, (get-content -path $sourceFile))
    $lookupTable = @{ }

    [xml]$xml = Get-Content $environmentFile
    $tmp = $adaptername -replace ".Runtime", "" 
    $tmp = $tmp -replace ".Acceptanstest", "" 
    $xpath = "environment/EIF[@name = '$tmp']" 
    $xml.SelectNodes($xpath) | ForEach-Object {$_.get_ChildNodes() } | ForEach-Object {
        $lookupTable.Add("@@{0}@@" -f $_.get_Name(), $_.InnerText)
    } 
    
    $lookupTable.GetEnumerator() | ForEach-Object { 		
        $b = $b -replace $_.Key, $_.Value 
    }
    $b | Set-Content -Path $destinationFile
}

function CreateEifDeploymentPackage {
param(
    $Name,
    $OutputRoot,
    $BaseDir,
    $Version,
    $BuildDir,
    $ToolsDir
)
    if($verbose) { Write-Output "-------------------------" }
    if($verbose) { Write-Output "  Creating Install package for EIF adapter:" }
    if($verbose) { Write-Output "  $Name-$Version.zip" }
    if($verbose) { Write-Output "-------------------------" }
    
    $accReleaseDir = "$OutputRoot"
    if((Test-Path $accReleaseDir\readme.txt) -ne $true) {
        Write-Output "Placeholder" > "$accReleaseDir\$Name.name"
    }
    $adapterBin  = "$accReleaseDir\AdapterPlugins"
    new-item $adapterBin -itemType directory -ErrorAction SilentlyContinue

    [xml]$deployFiles = Get-Content "$BaseDir\$Name\AdapterPluginFiles.xml"
    
    foreach($node in $deployFiles.files.get_ChildNodes()){
        $path = "$BuildDir\{0}" -f $node.InnerText
        cp -Path $path -Destination $adapterBin\. | Out-Null
    }
    # Copy over Tools
    new-item  $accReleaseDir\Tools -itemType directory -ErrorAction SilentlyContinue | Out-Null
    new-item  $accReleaseDir\Tools\TibcoAdmin -itemType directory -ErrorAction SilentlyContinue | Out-Null
    cp -Path "$base_dir\Tools\TibcoAdmin\*.*" -Destination $accReleaseDir\Tools\TibcoAdmin\. | Out-Null

    cp -Path "$base_dir\lib\EIF2.6\AdapterService.exe" -Destination $adapterBin\. | Out-Null

    # Copy all files from source regarding the following catalogs
    $catalogsToCopy = @("AdapterPlugins","Config","Logs","MsmqBackup","ProcessingStorage","Recover","ReliableSendStorage","Trace","XmlSchemas","XsltMappings","Config", "SharedLibrariesDirectory")
    foreach($catalog in $catalogsToCopy){
        new-item "$accReleaseDir\$catalog" -itemType directory -ErrorAction SilentlyContinue | Out-Null
        Copy-Item "$BaseDir\$Name\$catalog" -Destination "$accReleaseDir" -Recurse -Force -WarningAction SilentlyContinue | Out-Null
    }
    Get-ChildItem $accReleaseDir\* -include emptyfile.txt, placeholder.txt -recurse | Remove-Item
    Get-ChildItem $accReleaseDir\* -include .svn -recurse | ForEach-Object {
        Remove-Item "$_\*" -Recurse -Force | Out-Null
        Remove-Item $_ -Force | Out-Null
    }
    
    $eifEnviromentFile = "$BaseDir\$Name\Configuration.xml"
    if (Test-Path $eifEnviromentFile) {
        Get-ChildItem $base_dir\Environments\ -Filter *.xml | ForEach { 
            $destinationFile = "$OutputRoot\{0}.Configuration.xml" -f $_.Name
			
            replaceTokensEif -environmentFile $_.FullName -sourceFile $eifEnviromentFile -destinationFile $destinationFile -adaptername $Name
        }		
    }

    cp -Path "$base_dir\lib\EIF2.6\PowerShellInstallTemplates\*.ps1" -Destination $accReleaseDir\. | Out-Null
    
    $old = pwd
    cd $accReleaseDir
    $zipfile = "$name-$version.zip"
    exec {
            & $ToolsDir\zip.exe  -9 -A -r `
                $zipfile `
                *.*
         } | Out-Null
    cd $old
}
function CreateWebDeploymentPackage{
param(
    $Name,
    $OutputRoot,
    $BaseDir,
    $Version,
    $BuildDir,
    $ToolsDir
)
    if($verbose) { Write-Output "--------------------------------------------------" }
    if($verbose) { Write-Output "Creating zip file $Name-$Version.zip" }
    if($verbose) { Write-Output "--------------------------------------------------" }
    $accReleaseDir = "$OutputRoot" + "_PublishedWebsites\" + "$Name" + "_Package"
    $webFile = "$BaseDir\$Name\SetParameters.xml"
    
    if (Test-Path $webFile) {
        Get-ChildItem $base_dir\Environments\ -Filter *.xml | ForEach { 
            $destinationFile = "$accReleaseDir\{0}.SetParameters.xml" -f $_.Name
            replaceTokens -environmentFile $_.FullName `
                          -sourceFile $webFile `
                          -destinationFile $destinationFile `
                          -adaptername $Name
        }
    }
    $webFile = "$BaseDir\$Name\WebInstall.xml"
    
	cp $OutputRoot\*.ps1 $accReleaseDir\.

    if (Test-Path $webFile) {
        Get-ChildItem $base_dir\Environments\ -Filter *.xml | ForEach { 
            $destinationFile = "$accReleaseDir\{0}.WebInstall.xml" -f $_.Name
            replaceTokens -environmentFile $_.FullName `
                          -sourceFile $webFile `
                          -destinationFile $destinationFile `
                          -adaptername $Name
        }
    }

    $old = pwd
    cd $accReleaseDir
    $zipfile = "$name-$version.zip"
    exec {
            & $ToolsDir\zip.exe  -9 -A -r `
                $zipfile `
                *.*
         } | Out-Null
    Remove-Item . -Include *.zip -Exclude $zipfile		
    cd $old
}
function CreateDeploymentPackage{
param(
    $Name,
    $OutputRoot,
    $BaseDir,
    $Version,
    $BuildDir,
    $ToolsDir
)
    if($verbose) { Write-Output "--------------------------------------------------" }
    if($verbose) { Write-Output "Creating zip file $Name-$Version.zip" }
    if($verbose) { Write-Output "--------------------------------------------------" }
    $accReleaseDir = "$OutputRoot"
    if((Test-Path $accReleaseDir\readme.txt) -ne $true) {
        Write-Output "Placeholder" > $accReleaseDir\readme.txt
    }
    Write-Host "$BaseDir\$Name\DeployFiles.xml" -ForegroundColor Cyan
    [xml]$deployFiles = [xml](Get-Content "$BaseDir\$Name\DeployFiles.xml")
    
    foreach($node in $deployFiles.InstallFiles.get_ChildNodes()){
		if($node.GetAttribute("from") -eq "Source"){
        	$path = "$BaseDir\$Name\{0}" -f $node.InnerText
		}
		elseif ($node.GetAttribute("from") -eq "Package"){
        	$path = "$BaseDir\packages\{0}" -f $node.InnerText
		}
		else{
        	$path = "$BuildDir\{0}" -f $node.InnerText
		}
		if($node.GetAttribute("recurse") -eq "true"){
	        cp -Path $path -Destination $accReleaseDir -Recurse | Out-Null
		}
		else{
	        cp -Path $path -Destination $accReleaseDir\. | Out-Null
		}
    }

	$file = "Configuration.xml"
    if (Test-Path "$BaseDir\$name\$file") {
        Get-ChildItem $base_dir\Environments\ -Filter *.xml | ForEach { 
            $destinationFile = "$OutputRoot\{0}.$file" -f $_.Name
            replaceTokens -environmentFile $_.FullName `
                          -sourceFile "$BaseDir\$name\$file" `
                          -destinationFile $destinationFile `
                          -adaptername $Name
        }
    }

	$old = pwd
    cd $accReleaseDir
    $zipfile = "$name-$version.zip"
    exec {
            & $ToolsDir\zip.exe  -9 -A -r `
                $zipfile `
                *.*
         } | Out-Null
    cd $old
}
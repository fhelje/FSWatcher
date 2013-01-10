include .\properties.ps1

function GenerateNugetReferences($references)
{
    $nl = [Environment]::NewLine
    $refXml = ""
    $refXml += "    <references>$nl"
    $references.Files | % {
      if (![string]::IsNullOrEmpty( $_ )){
        $refXml += "      <reference file=""{0}"" />$nl" -f $_
      }
    }
    $references.Projects | % {
      if (![string]::IsNullOrEmpty( $_ )){
        $refXml += "  <reference file=""{0}.dll"" />$nl" -f $_
      }
    }
    $refXml += "    </references>$nl"
    return $refXml
}

function ParseNugetReferencies($project)
{
    Write-Host $project -ForegroundColor Magenta
    if (-not (Test-Path $project)) {
        Write-Host "Missing project file"
    }
    $content = [xml](gc "$project")
    $ns = @{'e'="http://schemas.microsoft.com/developer/msbuild/2003" }

    if (!($content.Project)) {  
        Write-Warning "Project $($_.FullName) skipped. Does not contain root tag with name Project"
        return
    }
        
    $ret = '' | select Files, Projects, xml

    # processing references to bin
    $ret.Files = Select-Xml -Xml $content -XPath '//e:Reference' -Namespace $ns |
        select -ExpandProperty Node | ? { $_.HintPath} |
        select -ExpandProperty HintPath |  ? { $_.StartsWith("..\lib") }
    $ret.Projects = Select-Xml -Xml $content -XPath '//e:ProjectReference' -Namespace $ns |
        select -ExpandProperty Node | ? { $_.Name} |
        select -ExpandProperty Name
    
    $ret.xml = GenerateNugetReferences($ret)
    $ret
}

function ParseNugetDependencies($deployfile)
{
    $xml = ""
    if (Test-Path $deployfile) 
    {
      $content = [xml](gc $deployfile)

      $nl = [Environment]::NewLine

      $xml += ""
      $xml += "    <dependencies>$nl"
      
      Select-Xml -Xml $content -XPath '//package' | select -ExpandProperty Node |% { 
        $tempP = $_.id
        $tempV = $_.version
        $xml += "      <dependency id=""$tempP"" version=""[$tempV]"" />$nl"
      }

      $xml += "    </dependencies>$nl"
    }
    else 
    {
      Write-Warning "Packages.config is missing"
      Write-Warning "Path: $deployfile"    
    }
  $xml
}

function CreateNugetSpecFile($Project, $Version, $Referencies, $Dependancies)
{
  $xml = ""
  $nl = [Environment]::NewLine

  Write-Host " ------------ " -ForegroundColor Cyan
  Write-Host "Proj: $Project" -ForegroundColor Cyan
  Write-Host " ------------ " -ForegroundColor Cyan
  Write-Host "Version: $Version" -ForegroundColor Magenta
  Write-Host " ------------ " -ForegroundColor Cyan
  Write-Host "Refs: $Referencies" -ForegroundColor Cyan
  Write-Host " ------------ " -ForegroundColor Cyan
  Write-Host "Deps: $Dependancies" -ForegroundColor Cyan
  Write-Host " ------------ " -ForegroundColor Cyan

  $xml += "<?xml version=""1.0""?>$nl"
  $xml += "<package>$nl"
  $xml += "  <metadata>$nl"
  $xml += "    <id>$Project</id>$nl"
  $xml += "    <version>$Version</version>$nl"
  $xml += "    <title>$proj</title>$nl"
  $xml += "    <authors>James Hammond</authors>$nl"
  $xml += "    <owners>Stralfors AB</owners>$nl"
  $xml += "    <projectUrl>http://195.66.94.245</projectUrl>$nl"
  $xml += "    <requireLicenseAcceptance>false</requireLicenseAcceptance>$nl"
  $xml += "    <description>Package for $Project</description>$nl"
  $xml += "    <releaseNotes></releaseNotes>$nl"
  $xml += "    <copyright>Copyright 2012 (C) Stralfors AB</copyright>$nl"
  $xml += "    <tags>NHSBT</tags>$nl"
  $xml += $Referencies
  $xml += $Dependancies
  $xml += "  </metadata>$nl"
  $xml += "</package>$nl"
  return $xml
}

function CreateNugetPackageStructure($proj)
{
  new-item "$base_dir\Nuget\$proj" -itemType directory -ErrorAction SilentlyContinue | Out-Null
  new-item "$base_dir\Nuget\packages" -itemType directory -ErrorAction SilentlyContinue | Out-Null
  new-item "$base_dir\Nuget\$proj\lib" -itemType directory -ErrorAction SilentlyContinue | Out-Null
  new-item "$base_dir\Nuget\$proj\lib\net40" -itemType directory -ErrorAction SilentlyContinue | Out-Null
  new-item "$base_dir\Nuget\$proj\tools" -itemType directory -ErrorAction SilentlyContinue | Out-Null
  new-item "$base_dir\Nuget\$proj\content" -itemType directory -ErrorAction SilentlyContinue | Out-Null
}
# exclude directories that end with host, test, acceptanstest, command, adapter, service, web
function GetProjectDirectories()
{
  $excludeEndings = @("host", "test", "acceptanstest", "command", "workercommand", "adapter", "service", "web")
  return gci .\ -recurse -include "*.csproj" | % { 
    
    $dir = Split-Path -parent $_ 
    $name = $dir.split("\") | Select-Object -Last 1 
    $type = $name.split(".") | Select-Object -Last 1 
    if ($excludeEndings -notcontains $type) {
        return $name
    }
  }
}

task NugetSpec {
  Write-Host "======================" -ForegroundColor Cyan
  Write-Host " NugetSpec task" -ForegroundColor Cyan

  $nugetDir = ".\Nuget"
  if (Test-Path $nugetDir) {
    rm $nugetDir -Recurse -Force
  }
  new-item $nugetDir -itemType directory
  GetProjectDirectories | Format-Table
  GetProjectDirectories | % {
    $proj = $_.split("\") | Select-Object -Last 1 
    CreateNugetPackageStructure($proj)
    $projFile = ".\{0}\{0}.csproj" -f $proj
    $refs = ParseNugetReferencies($projFile)
    # Copy files
    $from = ".\build\{0}.dll" -f $proj
	if(-not (Test-Path $from)){
		$from = ".\build\{0}.exe" -f $proj		
	}
    cp $from ".\Nuget\$proj\lib\net40\."

    $refs.Files | % {
      if (![string]::IsNullOrEmpty( $_ )){
        $from = ".\build\{0}.dll" -f $_
        cp $from ".\Nuget\$proj\lib\net40\."
      }
    }
    $refs.Projects | % {
      if (![string]::IsNullOrEmpty( $_ )){
        $from = ".\build\{0}.dll" -f $_
        cp $from ".\Nuget\$proj\lib\net40\."
      }
    }
    $depFile = ".\{0}\packages.config" -f $proj
    $deps = ParseNugetDependencies($depFile)

    $old = pwd
    cd $base_dir\Nuget\$proj

    $xml = $refs.xml
    CreateNugetSpecFile -Project $proj -Version $version -Referencies $xml -Dependancies $deps > .\$proj.nuspec

    cd $old
  }
}

task NugetPackage {
  Write-Host "======================" -ForegroundColor Cyan
  Write-Host " NugetPackage task" -ForegroundColor Cyan

  GetProjectDirectories | % {
    $proj = $_.split("\") | Select-Object -Last 1 
    $old = pwd
    cd $base_dir\Nuget\$proj
    $file = ".\{0}.nuspec" -f $proj
    exec { & ..\..\.nuget\nuget.exe pack "$file" }  
    $pack = $file = ".\{0}*.nupkg" -f $proj
    cp -path $pack -destination  ..\Packages  
    cd $old
  }
}

task NugetCopyToRelease{
  # Get-Childitems $root/Nuget/**/*.nupkg | cp $_ $root/Build/release/.
}


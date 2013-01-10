[CmdletBinding()]
param(
    [string]$dir='.'
)
function GenerateNugetReferences($references)
{
    $nl = [Environment]::NewLine
    $refXml = ""
    $refXml += "<references>$nl"
    $references | % {
        $refXml += "  <reference file=""{0}"" />$nl" -f $_
    }
    $refXml += "</references>$nl"
    return $refXml
}

Write-Host "Reading csprojs.."
function ParseNugetReferencies($project)
{
    $content = [xml](gc $project.FullName)
    $ns = @{'e'="http://schemas.microsoft.com/developer/msbuild/2003" }

    if (!($content.Project)) {  
        Write-Warning "Project $($_.FullName) skipped. Does not contain root tag with name Project"
        return
    }
        
    $ret = '' | select Files, ReferencesXml

    # processing references to bin
    $ret.Files = Select-Xml -Xml $content -XPath '//e:Reference' -Namespace $ns |
        select -ExpandProperty Node | ? { $_.HintPath} |
        select -ExpandProperty HintPath |  ? { $_.StartsWith("..\lib") }
    
    $ret.ReferencesXml = GenerateNugetReferences($ret.Files)
    return $ret
}
$dependencies = Get-ChildItem $dir *.csproj -Recurse | % { ParseNugetReferencies($_) }

Write-Host "=========="
Write-Host $dependencies 
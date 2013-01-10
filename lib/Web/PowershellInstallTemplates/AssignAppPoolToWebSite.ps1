##################################################################################
#
#  Set the app pool that a website should use
#  Script name: AssignAppPoolToWebSite.ps1
#  Author: Frank Heljebrandt
#
##################################################################################
param([string]$AppPoolName, [string]$WebSite, [switch]$help)

function GetHelp() {

$HelpText = @"

DESCRIPTION:

NAME: AssignAppPoolToWebSite.ps1
Set the websites application tool to the provided application pool


PARAMETERS: 

-AppPoolName   Name of the application pool to be used
-WebSite       The website to be used, if it is a Application within a website 
               use the following format: 'Default Web Site\TestApplication'
-help          Prints the HelpFile (Optional)

SYNTAX:

.\AssignAppPoolToWebSite.ps1 -AppPoolName "TestAppPool" -WebSite "Default Web Site\TestApplication"

Assing application pool to site or application

.\AssignAppPoolToWebSite.ps1 -help

Displays the helptext

"@
$HelpText
}

function AssignApplicationPoolTowebSite ([string]$appPoolName, [string]$webSite){

    $ws = Get-ChildItem IIS:\Sites\$webSite
    $pool = Get-ChildItem IIS:\AppPools | Where { $_.Name -eq "$AppPoolName" }
    if(-not $ws){
        throw "WebSite: {0} is missing" -f $webSite
    }
    if(-not $pool){
        throw "Application pool: {0} is missing" -f $pool
    }
    if($ws -and $pool){
        Set-ItemProperty IIS:\Sites\$webSite -name applicationPool -value $pool.name
    }
    else{
    }
}

if($help) { GetHelp; Continue }
if($AppPoolName -and  $WebSite) { 
    Import-Module WebAdministration
    AssignApplicationPoolTowebSite -appPoolName $AppPoolName `
                                   -webSite $WebSite 
}
else{
    GetHelp
}
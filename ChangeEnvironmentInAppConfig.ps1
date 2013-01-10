##################################################################################
#
#  Script name: ChangeEnvironmentInAppConfig.ps1
#
##################################################################################
param([bool]$AllToreplaceToken, [string]$Current, [string]$New, [switch]$help)
function GetHelp() {

$HelpText = @"

DESCRIPTION:

NAME: ChangeEnvironmentInAppConfig.ps1
Replaces all app settings with environment with value that matches current and 
replaces it with new


PARAMETERS: 

-Current            Old value that is to be replaced
-New                The new value
-AllToreplaceToken  Replace all hardcoded version to @@environment@@
-help               Prints the HelpFile (Optional)

SYNTAX:

.\ChangeEnvironmentInAppConfig.ps1 -Current "QA" -New "PROD"

.\ChangeEnvironmentInAppConfig.ps1 -help

Displays the helptext

"@
$HelpText
}
function replace([string]$current, [string]$new){

    Write-Host "From: $current, To: $new" -Foreground DarkGreen

    $from = '<add key="environment" value="' + $current + '"/>'
    $to = '<add key="environment" value="' + $new + '"/>'

    Get-ChildItem . -Filter app.config -Recurse -Name | ForEach-Object {
        [string]::join([environment]::newline, (Get-Content ".\$_")) -replace $from, $to | Set-Content -Path ".\$_"
    }
    
    Get-ChildItem . -Filter web.config -Recurse -Name | ForEach-Object {
        [string]::join([environment]::newline, (Get-Content ".\$_")) -replace $from, $to | Set-Content -Path ".\$_"
    }

}
if($help) { GetHelp; Continue }

if ($AllToreplaceToken) {

    Write-Host "Replacing all environments to @@environment@@ in all app.config files" -Foreground Cyan

    Get-ChildItem .\Environments\*.xml -Name | ForEach-Object { 
        $_.ToUpper() -replace ".xml", "" 
        replace -current ($_.ToUpper() -replace ".xml", "") -new "@@environment@@"
    } 

}

elseif ($Current -and $New) {

    Write-Host "Replacing from $Current to $New in all app.config files" -Foreground DarkCyan

    replace -current $Current -new $New

}
else {
    GetHelp; Continue    
}
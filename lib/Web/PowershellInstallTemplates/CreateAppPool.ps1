##################################################################################
#
#  Create app pool with sepcific user and .net framework version
#  Script name: CreateAppPool.ps1
#  Author: Frank Heljebrandt
#
##################################################################################

param([string]$AppPoolName, [string]$UserName, [string]$Password, [string]$FrameworkVersion = "v4.0", [switch]$help)

function GetHelp() {

$HelpText = @"

DESCRIPTION:

NAME: CreateAppPool.ps1
Create app pool with sepcific user and .net framework version
Defaultvalue for framework version is v4.0

PARAMETERS: 

-AppPoolName      Name of the application pool to be created
-UserName		  User to be used by the application pool
-Password		  Password for the user
-FrameworkVersion .Net Framework version that which the application pool should use
-help             Prints the HelpFile (Optional)

SYNTAX:

.\CreateAppPool.ps1 -AppPoolName "TestAppPool" -UserName "TestUser@stralfors.se" -Password "PassOrd1"

Create a new private queue with name Test

.\CreateAppPool.ps1 -help

Displays the helptext

"@
$HelpText
}

function CreateApplicationPool ([string]$AppPoolName, [string]$UserName, [string]$Password, [string]$FrameworkVersion) {
	$old = pwd
	$pool = Get-ChildItem IIS:\AppPools | Where { $_.Name -eq "$AppPoolName" }
	if(-not $pool){
		$pool = New-Item IIS:\AppPools\$AppPoolName
	}
	if(-not ($pool.processModel.username -eq $UserName)){
		$pool.processModel.username = $UserName
		$pool.processModel.password = $Password
		$pool.processModel.identityType = 3
		$pool | set-item 
	}
	if(-not ($pool.managedRuntimeVersion -eq $FrameworkVersion)){
		$pool | set-itemproperty -Name "managedRuntimeVersion" -Value $FrameworkVersion
	}	
	cd $old
}

if($help) { GetHelp; Continue }
if($AppPoolName -and  $UserName -and $Password ) { 
	Import-Module WebAdministration
	CreateApplicationPool -AppPoolName $AppPoolName `
						  -UserName $UserName `
						  -Password $Password `
						  -FrameworkVersion $FrameworkVersion
}
else{
	GetHelp
}
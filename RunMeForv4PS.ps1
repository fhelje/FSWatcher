if([IntPtr]::Size -eq 4){                        
	Write-Host "32 bit Windows"
	$file = $env:windir + "\System32\WindowsPowerShell\v1.0\"
}                        
Else{                        
	Write-Host "64 bit Windows"
	$file = $env:windir + "\SysWOW64\WindowsPowerShell\v1.0\"
}
cd $file
if(-not (Test-Path "$file\powershell.exe.config")){
	$filedata = @"
<?xml version="1.0"?>
<configuration>
  <startup useLegacyV2RuntimeActivationPolicy="true">
    <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.0"/>
  </startup>
</configuration>
"@
	$filedata | Out-File -FilePath ".\powershell.exe.config" -NoClobber 
}

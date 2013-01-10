function GID($HasScripts) {
                           $installFiles = ""
                           $nl = [Environment]::NewLine
                           $installFiles += '<?xml version="1.0" encoding="utf-8" ?>'
                           $installFiles += "$nl"
                           $installFiles += "<InstallFiles>$nl"
                           Get-ChildItem *.* -Include *.dll, *.exe, *.config -Exclude *.vshost.exe, *.vshost.exe.config | Sort-Object Name | ForEach-Object { 
                                                       $installFiles += "  <File>{0}</File>$nl" -f $_.Name
                                                       }
                           $installFiles += "</InstallFiles>"
                           Write-Output $installFiles
}

function GIDT($HasScripts) {
                           $installFiles = ""
                           $nl = [Environment]::NewLine
                           $installFiles += '<?xml version="1.0" encoding="utf-8" ?>'
                           $installFiles += "$nl"
                           $installFiles += "<InstallFiles>$nl"
                           Get-ChildItem *.* -Include *.dll, *.exe, *.config -Exclude *.vshost.exe, *.vshost.exe.config | Sort-Object Name | ForEach-Object { 
                                                       $installFiles += "  <File>{0}</File>$nl" -f $_.Name
                                                       }
                           $installFiles += "  <File>nunit.core.dll</File>$nl"
                           $installFiles += "  <File>nunit.core.interfaces.dll</File>$nl"
                           $installFiles += "  <File>nunit.util.dll</File>$nl"
                           $installFiles += "  <File>nunit-console-runner.dll</File>$nl"
                           $installFiles += "  <File>nunit-console-x86.exe</File>$nl"
                           $installFiles += "  <File>nunit-console-x86.exe.config</File>$nl"
                           if ($HasScripts) {
                            $installFiles += '  <File from="Source" recurse="true">InstallScripts</File>'                               
                            $installFiles += "$nl"
                           }
                           $installFiles += "</InstallFiles>"
                           Write-Output $installFiles
}

$old = pwd
$regular = @("*API*.Client", "*.Service", "*.Host", "*.Messages", "*.NHSBT.*Parser", "*.WorkerCommand");
Foreach ($filter in $regular){
    cd $old
    Foreach ($dir in Get-ChildItem $filter){
        $hasScript = Test-Path "$dir\InstallScripts"
        if($hasScript) { Write-Host $dir.Name }
        if (Test-Path "$dir\bin\debug") {
            cd "$dir\bin\debug"
            GID($hasScripts) > ..\..\DeployFiles.xml        
        }
    }
}
$tests = @("*.AcceptansTest");
Foreach ($filter in $tests){
    cd $old
    Foreach ($dir in Get-ChildItem $filter){
        $hasScript = Test-Path "$dir\InstallScripts"
        if($hasScript) { Write-Host $dir.Name }
        if (Test-Path "$dir\bin\debug") {
            cd "$dir\bin\debug"
            GIDT($hasScript) > ..\..\DeployFiles.xml        
        }
    }
}
cd $old
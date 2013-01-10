Properties {
  $lib_dir = "$base_dir\lib"
  $build_dir = "$base_dir\build"
  $buildartifacts_dir = "$build_dir\"
  $tools_dir = "$base_dir\Tools"
  $release_dir = "$build_dir\Release"
  $test_prjs = Get-VSSolution-TestProjectDlls $sln_file
  $web_prjs = Get-VSSolution-WebProjects $sln_file
  $acctest_prjs = Get-VSSolution-AcceptansTestProjectDlls $sln_file
#  $database_prjs = Get-VSSolution-DatabaseProjects $sln_file
  $database_prjs = @("Stralfors.NHSBT.Import.Database")
  $environment = "Build"
  $artifact_dir = $release_dir
  $buildCounter = 0
  $revision = 0
  $installScripts = @{
                        "host" = "$base_dir\lib\NServiceBus\PowershellInstallTemplates\*.ps1"; 
                        "service" = "$base_dir\lib\TopShelf\PowershellInstallTemplates\*.ps1"; 
                        "adapter" = "$base_dir\lib\EIF2.6\PowershellInstallTemplates\*.ps1";
                        "web" = "$base_dir\lib\Web\PowershellInstallTemplates\*.ps1";
                        "workercommand" = "$base_dir\lib\Console\PowershellInstallTemplates\*.ps1"
                        "selfhost" = "$base_dir\lib\selfhost\PowershellInstallTemplates\*.ps1"
                        "acceptanstest" = "$base_dir\lib\acceptanstest\PowershellInstallTemplates\*.ps1"
                        "tool" = "$base_dir\lib\tool\PowershellInstallTemplates\*.ps1"
                     }
}

$nugetExec = "$base_dir\.NuGet\nuget.exe"
$nugetDir = "$buildDir\NuGet"


include .\psake_ext.ps1
#Import-Module .\Tools\Powershell\Build\Build.psd1


task Verify40 {
    if( (ls "$env:windir\Microsoft.NET\Framework\v4.0*") -eq $null ) {
        throw "Building DRS requires .NET 4.0, which doesn't appear to be installed on this machine"
    }
}

task CleanInstallDir {
  remove-item -force -recurse "$base_dir\Installdir" -ErrorAction SilentlyContinue 
}

task Clean {
  remove-item -force -recurse $buildartifacts_dir -ErrorAction SilentlyContinue 
}

task MakeTestOutputDirs {

    new-item $build_dir -itemType directory -ErrorAction SilentlyContinue 
    new-item "$build_dir\Output" -itemType directory -ErrorAction SilentlyContinue 
    new-item "$build_dir\TestResults" -itemType directory -ErrorAction SilentlyContinue 
    new-item "$build_dir\AcceptansTest" -itemType directory -ErrorAction SilentlyContinue 
    new-item "$base_dir\Installdir" -itemType directory -ErrorAction SilentlyContinue 
    
}

task Init -depends Verify40, Clean, MakeTestOutputDirs {


    $projectFiles = ls -path $base_dir -include *.csproj -recurse | 
                    Where { $_ -notmatch [regex]::Escape($lib_dir) } | 
                    Where { $_ -notmatch [regex]::Escape($tools_dir) }

    $notclsCompliant = @("")

    foreach($projectFile in $projectFiles) {

        $projectDir = [System.IO.Path]::GetDirectoryName($projectFile)
        $projectName = [System.IO.Path]::GetFileName($projectDir)
        $asmInfo = [System.IO.Path]::Combine($projectDir, [System.IO.Path]::Combine("Properties", "AssemblyInfo.cs"))

        $clsComliant = "false"

        if([System.Array]::IndexOf($notclsCompliant, $projectName) -ne -1) {
            $clsComliant = "false"
        }

        Generate-Assembly-Info `
            -file $asmInfo `
            -title "$projectName $version.0" `
            -description "Polling file system watcher replacement" `
            -company "" `
            -product "FSWatcher $version.0" `
            -version "$version.0" `
            -fileversion "$version.$buildCounter" `
            -copyright "Copyright 2010" `
            -clsCompliant $clsComliant
    }

	foreach($dbPrj in $database_prjs){
        
        if (![string]::IsNullOrEmpty( $dbPrj )){
            $buildInfo = [System.IO.Path]::Combine($dbPrj, "buildInfo.xml")
            Generate-Build-Info -file $buildInfo
            MakeRoundHousEDirectories -prjName $dbPrj -outputRoot "$buildartifacts_dir\"
        }
    }    

}

task Compile -depends Init {

    $v4_net_version = (ls "$env:windir\Microsoft.NET\Framework\v4.0*").Name
    
    try { 
        $msoutdir = '{0}' -f "$buildartifacts_dir"
        exec { &"$env:windir\Microsoft.NET\Framework\$v4_net_version\MSBuild.exe" "$sln_file" /p:DefineConstants=PSAKE /p:OutDir="$msoutdir" /verbosity:"$msbuildverbosity" }
        foreach($dbPrj in $database_prjs){
            if (![string]::IsNullOrEmpty( $dbPrj )){
              if(Test-Path "$base_dir\$dbPrj")
              {
                CopyDatabaseFiles -projectDirectory	"$base_dir\$dbPrj" -outputDirectory "$buildartifacts_dir\$dbPrj"
              }
              else
              {
                Write-Host "WARNING: Database project is missing, this might be ok if you build db project in different project on build server" -ForegroundColor Magenta
              }                
            }
        }
        # Sgen message dlls
        $messageDlls = Get-VSSolution-MessagesProjects $sln_file
        if([IntPtr]::Size -eq 4){                        
            $sgenPath = "$env:ProgramFiles\Microsoft SDKs\Windows\v7.0A\bin\NETFX 4.0 Tools\sgen.exe"
        }                        
        Else{                        
            $sgenPath = "$env:ProgramFiles (x86)\Microsoft SDKs\Windows\v7.0A\bin\NETFX 4.0 Tools\sgen.exe"
        }
        foreach($mprj in $messageDlls){
            if (![string]::IsNullOrEmpty( $mprj )){
                $mdll = "{0}.dll" -f $mprj
                #exec { &"$sgenPath" /assembly:"$build_dir\$mdll" /out:"$buildartifacts_dir\" /verbose }		
            }
        }
    } catch {
        Throw
    } 
}
task Generate-Schemas {
    CreateSchemas -build_dir $build_dir -output "$build_dir\Output"
}
task Test -depends Compile{
  $old = pwd
  cd $build_dir
  foreach($test_prj in $test_prjs) {
    if(Test-Path $build_dir\$test_prj) {
        $testoutput = "$build_dir\TestResults\$test_prj" -replace ".dll", ".xml"
        exec { &"$build_dir\nunit-console-x86.exe" "$build_dir\$test_prj" /xml=$testoutput /trace=verbose /noshadow /nologo} 
    }
  }
  cd $old
}
task InstallDatabases {
    $install_base = "$base_dir\Installdir"
    New-Item $install_base -ItemType directory -ErrorAction SilentlyContinue | out-null
    $install_databases = "$install_base\Databases"
    New-Item $install_databases -ItemType directory -ErrorAction SilentlyContinue | out-null
    try{

        $old = pwd

        foreach($dbPrj in $database_prjs){
            if (![string]::IsNullOrEmpty( $dbPrj )){
                $dbName = GetDbName -solution $dbPrj
                
                New-Item $install_databases\$dbName -ItemType directory -ErrorAction SilentlyContinue | out-null
                cd $install_databases\$dbName
                $versionFile = "$dbPrj\_buildInfo.xml"
                # Copy db zip to testinstall dir
                Get-ChildItem $artifact_dir\* -Filter "$dbName*.zip" | ForEach {
                    cp $_ -Destination $install_databases\$dbName -Recurse
                    exec { & "$tools_dir\unzip.exe" -q $_.Name }
                }
                # Run roundhouse 
                $buildcommand = Get-ChildItem * -Filter "$environment*.Drop.bat"	| Select-Object -First 1
                exec { & $buildcommand }
                $buildcommand = Get-ChildItem * -Filter "$environment*.DBDeployment.bat"	| Select-Object -First 1
                exec { & $buildcommand }
                cd $old
            }
        }
    } catch {
        Throw
    } finally { 

    }
}
task InstallAndRunAcceptansTests {
    $install_base = "$base_dir\Installdir"
    New-Item $install_base -ItemType directory -ErrorAction SilentlyContinue
    try{

        $old = pwd
        foreach($acctest in $acctest_prjs){
            $accname = $acctest -replace ".dll", ""
            # Run preacceptanstest.ps1
            
            $accDep = "$base_dir\$accname\AcceptanstestDependancies.xml"
            if($verbose) { Write-Host "------------------------------------" -ForegroundColor Magenta }
            if($verbose) { Write-Host "|  Acctest $accname                |" -ForegroundColor Magenta }
            if($verbose) { Write-Host "------------------------------------" -ForegroundColor Magenta }
            $install_acctest = "$install_base\$accname"
            $accresult = "$build_dir\AcceptansTest\AcceptansTest.$accname.xml"
            $accresulttxt = "$build_dir\AcceptansTest\AcceptansTest.$accname.txt"
            New-Item $install_acctest -ItemType directory -ErrorAction SilentlyContinue | Out-Null
            
            # copy zip
            cd $install_acctest
            Get-ChildItem $artifact_dir\* -Filter "$accname*.zip" | ForEach {
                cp $_ -Destination $install_acctest -Recurse
                exec { & "$tools_dir\unzip.exe" -q $_.Name } | Out-Null
            }
            $config = "{0}.config" -f $acctest
            $buildEnv = Get-ChildItem $install_base\Environments -Filter "$environment*.xml" | Select-Object -First 1 
            
            replaceTokens -sourceFile $install_acctest\$config `
                          -environmentFile $buildEnv.Fullname `
                          -destinationFile "$install_acctest\$config" `
                          -adaptername @accname
            if (Test-Path "$install_acctest\InstallScripts\PreDependanciesInstall.ps1") {
              $revert = pwd
              cd "$install_acctest\InstallScripts"
              exec { & "$install_acctest\InstallScripts\PreDependanciesInstall.ps1" $environment }
              cd $revert
            }
            else{
              Write-Host "Unable to find install script for acc test:" -ForegroundColor DarkCyan
              Write-host "$install_acctest\InstallScripts\Install.ps1" -ForegroundColor DarkCyan
            }
            #Get dependancies
            if (Test-Path $accDep){
                if($verbose) { Write-Host $accDep -ForegroundColor Cyan }
                [xml]$dep = Get-Content $accDep
                foreach($node in $dep.dependancies.get_ChildNodes()){
                    # Create dir for dependancy			
                    $dir = "$install_acctest\{0}" -f $node.installsubdir
                    New-Item $dir -ItemType directory -ErrorAction SilentlyContinue | Out-Null
                    cd $dir					
                    Get-ChildItem $artifact_dir\* -Filter $node.artifact | ForEach {
                        cp $_ -Destination $dir -Recurse
                        exec { & "$tools_dir\unzip.exe" -q $_.Name } | Out-Null
                        exec { & $node.installcommand $environment }
                    }
                    cd ..
                }
            }
            if (Test-Path "$install_acctest\InstallScripts\Install.ps1") {
              $revert = pwd
              cd "$install_acctest\InstallScripts"
              exec { & "$install_acctest\InstallScripts\Install.ps1" $environment }
              cd $revert
            }
            else{
              Write-Host "Unable to find install script for acc test:" -ForegroundColor DarkCyan
              Write-Host "$install_acctest\InstallScripts\Install.ps1" -ForegroundColor DarkCyan
            }
            try{
                $testConf = "{0}.dll.config" -f $accname
                if(Test-Path $testConf) {
                     $envFile = "$environment.xml.Configuration.xml"
                    if(Test-Path .\$envFile){
                        replaceTokens -sourceFile .\$testConf `
                                      -environmentFile .\$envFile `
                                      -destinationFile "$testConf" `
                                      -adaptername $accname
                    }
                }
                exec { &"$install_acctest\nunit-console-x86.exe" "$install_acctest\$acctest" /labels /out=$accresulttxt /xml=$accresult /noshadow /nologo } 
            } catch {
                Throw
            }
            finally{
            
                #uninstall prereq
                if (Test-Path $accDep){
                    foreach($node in $dep.dependancies.get_ChildNodes()){
                        $dir = "$install_acctest\{0}" -f $node.installsubdir
                        cd $dir
                        try {
                            exec { & $node.uninstallcommand $environment }
                        } catch {
                            Write-Host $dir -ForegroundColor Red
                            Write-Host $node.uninstallcommand -ForegroundColor Red
                        }
                        cd ..
                    }
                }				
            }
            exec { &"$base_dir\packages\SpecFlow.1.9.0\tools\specflow.exe" nunitexecutionreport "$base_dir\$accname\$accname.csproj" /xmlTestResult:"$accresult" /out:"$base_dir\build\TestResults\$accname.html" }
            exec { &"$base_dir\packages\SpecFlow.1.9.0\tools\specflow.exe" stepdefinitionreport "$base_dir\$accname\$accname.csproj" /out:"$base_dir\build\TestResults\$accname.stepreport.html" }
            
            # Run postacceptanstest.ps1
        }
        cd $old
    } catch {
        Throw
    } finally { 

    }

}
task InstallEnvironments {
    $old = pwd
    $install_base = "$base_dir\Installdir"
    New-Item $install_base -ItemType directory -ErrorAction SilentlyContinue | Out-Null
    $install_env = "$install_base\Environments"
    New-Item $install_env -ItemType directory -ErrorAction SilentlyContinue | Out-Null
    cd $install_env
    Get-ChildItem $build_dir\Release\* -Filter "Environments*.zip" | ForEach {
        cp $_ -Destination $install_env -Recurse
        exec { & "$tools_dir\unzip.exe" -q $_.Name } | Out-Null
    }
    cd $old
}
task AccTest -depends CleanInstallDir, MakeTestOutputDirs, InstallDatabases, InstallEnvironments, InstallAndRunAcceptansTests {

}
task CreateOutputDirectories -depends CleanOutputDirectory {
    mkdir $build_dir\Output | Out-Null
    mkdir $build_dir\Output\Schemas | Out-Null
    mkdir $build_dir\Output\Environments | Out-Null
    mkdir $build_dir\Output\Databases\ | Out-Null    
}
task CopyDatabases -depends CreateRHInstallCommandFiles {
  foreach($dbPrj in $database_prjs){
    if (![string]::IsNullOrEmpty( $dbPrj )){
      if(Test-Path $buildartifacts_dir\$dbPrj)
      {
        $dbProjPath = "$base_dir\$dbPrj"
Write-Host $dbProjPath -ForegroundColor Yellow
        if(Test-Path $dbProjPath)
        {
Write-Host $dbProjPath -ForegroundColor Yellow
          $dbName = GetDbName -solution $dbPrj
          $outDir = "$build_dir\Output\Databases\$dbName"
          copy-item -rec -filter *.* $buildartifacts_dir\$dbPrj\ $outDir  | Out-Null
          copy-item -Path $tools_dir\RoundHousE\RH.exe -Destination $outDir\. | Out-Null
          $zipfile = "$dbName-Database-$version.zip"
          $old = pwd
          cd $outDir
          exec { & $tools_dir\zip.exe  -q -9 -A -r $zipfile *.* } | Out-Null
          cd $old
        }
      }
    }
  }
}



task CreateRHInstallCommandFiles {
  $rhInstallCmd = ".DBDeployment.bat"
  $rhDropCmd= ".Drop.bat"
  foreach($dbPrj in $database_prjs){
    if (![string]::IsNullOrEmpty( $dbPrj )){
      if(Test-Path $buildartifacts_dir\$dbPrj)
      {
        if(Test-Path $build_dir\$dbPrj)
        {
            $dbName = GetDbName -solution $dbPrj
            $outCatalog = "$build_dir\Output\Databases\$dbName"
            $environments = Get-ChildItem $base_dir\Environments	
            foreach($env in $environments){
                [xml]$envXml = get-content $env.Fullname
                
                $tempDbName = "Stralfors.NHSBT.Import.Database";

                InsertVersionAttributeInEnvironmentSqlFiles -sqlEnvironmentFilesDirectory  $build_dir\$tempDbName\Permissions -tokensToReplace "@@VERSION@@" -replacementValue  "$version.0"
                InsertVersionAttributeInEnvironmentSqlFiles -sqlEnvironmentFilesDirectory  $build_dir\$tempDbName\runAfterOtherAnyTimeScript -tokensToReplace "@@VERSION@@" -replacementValue  "$version.0"

                $filename = $envxml.environment.name + $rhInstallCmd
                Generate-RoundHousE-Cmd -file $outCatalog\$filename `
                    -databaseName $envxml.environment.database.database `
                    -serverDatabase $envxml.environment.database.servername `
                    -sqlFilesDirectory $dbPrj `
                    -repositoryPath $repositoryPath `
                    -environment $envxml.environment.name 
                    
                $filename = $envxml.environment.name + $rhDropCmd
                Generate-RoundHousE-Drop-Cmd -file $outCatalog\$filename `
                    -databaseName $envxml.environment.database.database `
                    -serverDatabase $envxml.environment.database.servername `
                    -sqlFilesDirectory $dbPrj `
                    -repositoryPath $repositoryPath `
                    -environment $envxml.environment.name 
          }
        }
      }
    }
  }
}
task CopyEnvironments {
    $envDir = "$build_dir\Output\Environments"
    Write-Output "Placeholder" > $envDir\readme.txt
    cp -Path "$base_dir\Environments\*.xml" -Destination $envDir\.
}
task CreateBuildArtifactsForDeployFiles {
    Get-ChildItem * -Recurse -Include DeployFiles.xml -Exclude Tools, Build, Installdir | ForEach-Object {
        $pathArr = $_.Fullname.Split('\')
        $baseArr = "$base_dir".Split('\')
        $name = $pathArr[$baseArr.Length]
        $programTypeArr = $name.Split('.') 
        $programType = $programTypeArr[$programTypeArr.Length-1]
        
        New-Item "$build_dir\Output\$name" -ItemType directory -ErrorAction SilentlyContinue | Out-Null

        if($installScripts.ContainsKey($programType))
        {
            cp -Path $installScripts.Get_Item($programType) -Destination $build_dir\Output\$name\. | Out-Null
        }
        CreateDeploymentPackage -Name $name -OutputRoot "$build_dir\Output\$name" -BaseDir $base_dir -Version $version -BuildDir $build_dir -ToolsDir $tools_dir
    }
}
task Package {
    $v4_net_version = (ls "$env:windir\Microsoft.NET\Framework\v4.0*").Name
    foreach($web_prj in $web_prjs){
        $m = '{0}output' -f "$buildartifacts_dir"
        $msoutdir = "$m\$web_prj\"
        $csproj = "$base_dir\$web_prj\$web_prj.csproj"
        if(Test-Path $csproj) {
            exec { &"$env:windir\Microsoft.NET\Framework\$v4_net_version\MSBuild.exe" "$csproj" /p:OutDir="$msoutdir" /t:Package /verbosity:"$msbuildverbosity"  }

            #Create Set-parameters.xml for each environment
            if($installScripts.ContainsKey("web"))
            {
                cp -Path $installScripts.Get_Item("web") -Destination $msoutdir\. | Out-Null
            } 
            CreateWebDeploymentPackage -Name $web_prj `
                                       -OutputRoot $msoutdir `
                                       -BaseDir $base_dir `
                                       -Version $version `
                                       -BuildDir $build_dir `
                                       -ToolsDir $tools_dir
        }
    }
}
task CreateEIFBuildArtifactsForDeployFiles {
    if (Test-Path "$base_dir\Lib\Eif2.6\Altova.AltovaXML.dll") {
        cp -Path "$base_dir\Lib\Eif2.6\Altova.AltovaXML.dll" -Destination $build_dir\. -WarningAction SilentlyContinue | Out-Null
        Get-ChildItem * -Recurse -Include AdapterPluginFiles.xml -Exclude Tools, Build, Installdir | ForEach-Object {
            $pathArr = $_.Fullname.Split('\')
            $baseArr = "$base_dir".Split('\')
            $name = $pathArr[$baseArr.Length]
            New-Item "$build_dir\Output\$name" -ItemType directory -ErrorAction SilentlyContinue | Out-Null
            CreateEifDeploymentPackage -Name $name -OutputRoot "$build_dir\Output\$name" -BaseDir $base_dir -Version $version -BuildDir $build_dir -ToolsDir $tools_dir
        }
    }
}
task DoRelease -depends Test, `
                        CreateOutputDirectories, `
                        Package, `
                        CopyEnvironments, `
                        CopyDatabases, `
                        CreateBuildArtifactsForDeployFiles, `
                        CreateEIFBuildArtifactsForDeployFiles, `
                        CreateRHInstallCommandFiles, `
                        CopyZipToRelease, `
                        ZipAndCopyTestToRelease, `
                        ZipAndCopyEnvironments, `
                        ZipAndCopyAcceptansTestToRelease,
						CreateNugetPackages
{
}



task ZipAndCopyTestToRelease {
    #new-item "$build_dir\Release" -itemType directory -ErrorAction SilentlyContinue
    $old = pwd
    cd $build_dir\TestResults
    $zipfile = "TestResults-$version.zip"
    if(Test-Path *.*){ 
        exec { & $tools_dir\zip.exe  -q -9 -A -r $zipfile *.* } | Out-Null
        cp $zipfile -Destination $build_dir\Release\. -Recurse | Out-Null
    }
    cd $old
}

task ZipAndCopyAcceptansTestToRelease {
    $old = pwd
    cd $build_dir\AcceptansTest
    if(Test-Path *.*){
        $zipfile = "AcceptansTest-$version.zip"
        
        exec { & $tools_dir\zip.exe  -q -9 -A -r $zipfile *.* } | Out-Null
        cp $zipfile -Destination $build_dir\Release\. -Recurse | Out-Null
    }
    cd $old
}

task ZipAndCopyEnvironments {
    #new-item "$build_dir\Release" -itemType directory -ErrorAction SilentlyContinue
    $old = pwd
    cd $build_dir\output\Environments
    $zipfile = "Environments-$version.zip"
    exec {
            & $tools_dir\zip.exe  -q -9 -A -r `
                $zipfile `
                *.*
         } | Out-Null
    cp $zipfile -Destination $build_dir\Release\. -Recurse | Out-Null
    cd $old
}

task CopyZipToRelease {
    new-item "$build_dir\Release" -itemType directory -ErrorAction SilentlyContinue | Out-Null
    $old = pwd
    cd $build_dir\Output
    Get-ChildItem * -Include *.zip -Recurse | cp -Destination $build_dir\Release\. -Recurse
    cd $old
}

task CopyDBFromDependentSolution {
  foreach($dbPrj in $database_prjs)
  {
    if (![string]::IsNullOrEmpty( $dbPrj ))
    {
      if(-not (Test-Path $base_dir\$dbPrj))
      {
        if (![string]::IsNullOrEmpty( $dependentDatabaseSolutionPath )){
          $dbName = GetDbName -solution $dbPrj
          cp "$dependentDatabaseSolutionPath\build\release\$dbname-*.zip" "$base_dir\build\release\."
        }
      }
    }
  }  
}

task CleanOutputDirectory { 
    remove-item $build_dir\Output -Recurse -Force  -ErrorAction SilentlyContinue | Out-Null
}

task VerifyCheckin -depends DoRelease, CopyDBFromDependentSolution, AccTest, CreateSpecificationPackage {
    
}

task CreateNugetPackages{
	dir $outputDir -recurse -include *.nuspec | % {
		$nuspecfile = $_.FullName  
        #exec { &$nugetExec pack $nuspecfile -OutputDirectory $artifactsDir -Version "$ProductVersion.$BuildCounter"}
	}
}

task CreateSpecificationPackage {
    [xml]$xml = Get-Content "$base_dir\PublicSpecification.xml"
    $to = "$build_dir\Output\Specifications"
    if (!(Test-Path $to)) {
        mkdir $to
    }
    cp "$base_dir\PublicSpecification.xml" $to
    $xml.SelectNodes("specifications/feature") | ForEach-Object {$_.get_ChildNodes() } | ForEach-Object {
        $from = "$base_dir\{0}" -f $_.InnerText;
        if (Test-Path $from) {
            cp $from $to
        }
    }
    if ((get-childitem $to -name).count -gt 0) {
        $old = pwd
        cd $to
        $zipfile = "Specifications-$version.zip"
        exec {
                & $tools_dir\zip.exe  -q -9 -A -r `
                    $zipfile `
                    *.*
             } 
        if (Test-Path $zipfile) {
            cp $zipfile -Destination $build_dir\Release\. -Recurse | Out-Null        
        }
        cd $old
    }
}
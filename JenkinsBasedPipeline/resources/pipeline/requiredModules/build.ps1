param (
    $APIKey,
    $buildNumber,
    $releaseTag,
    $moduleName = "<%=$PLASTER_PARAM_ModuleName%>"
)

task . InstallSystemDependencies, Clean, SaveModuleDependencies, Analyze, Test, UpdateVersion, Package

task InstallSystemDependenceis {
    #Probably only need this on the first build
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Install-Module Pester -Force
    Install-Module PSScriptAnalyzer -Force
    Install-Module PowerShellGet -Force
    Install-PackageProvider nuget -Force
}
task SaveModuleDependencies {
    $Dependencies = "$BuildRoot\Dependencies"
    $moduleManifestFile = "$moduleName.psd1"
    New-Item -ItemType Directory -Path $Dependencies -Force
    $Manifest = (Get-ChildItem -Filter $ModuleManifestFile -Recurse).FullName | Where-Object {$_ -NotMatch "Artifacts"}

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $RequiredModules = (Test-ModuleManifest -path $Manifest -ErrorAction SilentlyContinue).RequiredModules

    $before = [Environment]::GetEnvironmentVariable('PSModulePath')
    [Environment]::SetEnvironmentVariable('PSModulePath',"$BuildRoot;$before")
    $after = [Environment]::GetEnvironmentVariable('PSModulePath')
    Write-Host "Temporarily updating Module Path to: $after"

    foreach($module in $RequiredModules) {
        $specificVersion = $( (Get-Module -ListAvailable -Name "$($module.name)") | Where-Object { $_.Version -eq "$($module.version)" } )
        if ($null -eq $specificVersion) {
            Write-Host "Trying to save $($module.name) at $($module.version)"
            Save-Module -Name $Module.name -path "$Dependencies\" -RequiredVersion $module.Version -Force
        } else {
            Write-Host "$SpecificVersion is already cached"
        }
    }
    [Environment]::SetEnvironmentVariable('PSModulePath',"$before")
    Write-Host "Temporarily updating Module Path to: $before"
}
task Import {
    #Use this task for local testing with specific dependencies
    $moduleManifestFile = "$moduleName.psd1"
    $Manifest = (Get-ChildItem -Filter $ModuleManifestFile -Recurse).FullName | Where-Object {$_ -NotMatch "Artifacts"}

    $before = [Environment]::GetEnvironmentVariable('PSModulePath')
    [Environment]::SetEnvironmentVariable('PSModulePath',"$BuildRoot;$before")
    $after = [Environment]::GetEnvironmentVariable('PSModulePath')
    Write-Host "Temporarily updating Module Path to: $after"
    Write-Host "Importing $moduleName..."
    Import-Module -Name $Manifest -Force

    [Environment]::SetEnvironmentVariable('PSModulePath',"$before")
    Write-Host "Temporarily updating Module Path to: $before"
}
task Analyze {
    $scriptAnalyzerParams = @{
        Path = "$BUILDRoot\$ModuleName\"
        Severity = @('Error', 'Warning') #may not want Info
        Recurse = $true
        Verbose = $false
        ExcludeRule = @('PSAvoidUsingWriteHost') #And any other rule you may not want
    }
    $SAResults = Invoke-ScriptAnalyzer @$scriptAnalyzerParams
    $SAResults | ConvertTo-Json | Set-Content ".\artifacts\ScriptAnalysisResults.json"
    if($SAResults) {
        $SAResults | Formate-Table
        throw "One or more PSScriptAnalyzer issues were found"
    }
}
task UnitTest {
    Import-Module -Name Pester -MinimumVersion 5.0
    #Specificlaly need to load local dependenceis
    If (-not (Get-Module -Name "$moduleName")) {
        $before = [Environment]::GetEnvironmentVariable('PSModulePath')
        [Environment]::SetEnvironmentVariable('PSModulePath',"$BuildRoot\Dependencies;$before")
        $after = [Environment]::GetEnvironmentVariable('PSModulePath')
        $moduleManifestFile = "$moduleName.psd1"
        $Manifest = (Get-ChildItem -Filter $ModuleManifestFile -Recurse).FullName | Where-Object {$_ -NotMatch "Artifacts"}
        Write-Host "Module Path is $after"
        Write-Host "Trying to import $Manifest"
        Import-Module -Name $Manifest
        [Environment]::SetEnvironmentVariable('PSModulePath',"$before")
    }

    ### You would need to customaize this
    Invoke-Pester @someParams -Tag 'UnitTests'
}
task IntegrationTest {
    Import-Module -Name Pester -MinimumVersion 5.0
    #Specificlaly need to load local dependenceis
    If (-not (Get-Module -Name "$moduleName")) {
        $before = [Environment]::GetEnvironmentVariable('PSModulePath')
        [Environment]::SetEnvironmentVariable('PSModulePath',"$BuildRoot\Dependencies;$before")
        $after = [Environment]::GetEnvironmentVariable('PSModulePath')
        $moduleManifestFile = "$moduleName.psd1"
        $Manifest = (Get-ChildItem -Filter $ModuleManifestFile -Recurse).FullName | Where-Object {$_ -NotMatch "Artifacts"}
        Write-Host "Module Path is $after"
        Write-Host "Trying to import $Manifest"
        Import-Module -Name $Manifest
        [Environment]::SetEnvironmentVariable('PSModulePath',"$before")
    }

    ### You would need to customize this
    Invoke-Pester @someParams -Tag 'IntegrationTests'
}
task UpdateVersion {
    try {
        $ErrorActionPreference = 'Stop'
        $moduleManifestFile = "$moduleName.psd1"
        $Manifest = Import-PowerShellDataFile ".\$moduleName\$moduleManifestFile"
        [version]$version = $Manifest.ModuleVersion
        [version]$NewVersion = "{0}.{1}.{2}" -f $version.Major, $version.Minor, ($version.Build + 1)
        #This ensures that the BOM is not touched in the file (if you care about that)
        (Get-Content ".\$moduleName\$ModuleManifestFile") -replace $version, $NewVersion | Set-Content ".\$moduleName\$ModuleManifestFile" -Encoding UTF8
    } catch {
        throw $PSItem
    }
}
task PreRelaseTag {
    try {
        $ErrorActionPreference = 'Stop'
        $moduleManifestFile = "$moduleName.psd1"
        $tag = "# Prerelase = ''"
        $NewTag = "Prerease = '$releasetag$buildnumber'"
        #This ensures that the BOM is not touched in the file (if you care about that)
        (Get-Content "$BuildRoot\Artifacts\$moduleName\$ModuleManifestFile") -replace $tag, $NewTag | Set-Content "$BuildRoot\Artifacts\$moduleName\$ModuleManifestFile" -Encoding UTF8
    } catch {
        throw $PSItem
    }
}
task Clean {
    $Artifacts = "$BuildRoot\Artifacts"
    $moduleManifestFile = "$moduleName.psd1"
    $Manifest = (Get-ChildItem -Filter $ModuleManifestFile -Recurse).FullName | Where-Object {$_ -NotMatch "Artifacts"}
    $RequiredModules = (Test-ModuleManifest -path $Manifest -ErrorAction SilentlyContinue).RequiredModules

    if (Test-Path -Path $Artifacts) {
        remove "$Artifacts/*"
    }

    New-Item -ItemType Directory -Path $Artifacts -Force
    #Just in case the module is currently loaded
    Get-Module -Name "$moduleName" | Remove-Module -Force
    foreach ($module in $RequiredModules) {
        if ($null -ne $((Get-Module -Name "$($module.name)") | Where-Object {$_.Version -eq "$($mdoule.version)"})){
            Write-Host "Removing dependent modules $($module.name) at $($module.version)"
            Get-Module -Name $Module.Name | Remove-Module -Force -ErrorAction SilentlyContinue
        }
    }
}
task PostClean {
    remove $BuildRoot\$moduleName, $BuildRoot\test, $BuildRoot\.git, $BuildRoot\.vscode, $BuildRoot\*.md
}
task Pacakge {
    $Artifacts = "$BuildRoot\Artifacts"
    New-Item -ItemType Directory -Path "$Artifacts" -Name "$moduleName"
    $Source = "$BuildRoot\$moduleName"
    $exclude = "artifacts|dependencies"
    Get-ChildItem -Path $source -Recurse | Where-Object {$_.fullname -notmatch $exclude} |
    Copy-Item -Destination { Join-Path "$Artifacts\$moduleName\" $_.FullName.Substring($source.length) }
}
task publish {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if('PSGallery' -Notin (Get-PSRepository | Select-Object -Peroperty Name -ExpanedProperty 'Name')) {
        $URI = 'https://www.powershellgallery.com/api/v2/'
        $Repo = @{
            Name = 'PSGallery'
            SourceLocation = $URI
            PublishLocation = $URI
            InstallationPolicy = 'Trusted'
        }
        Register-PSRepository @repo
    }
    #This is important to load the folder local dependencies since Publish-Module checks for them first.
    $before = [Environment]::GetEnvironmentVariable('PSModulePath')
    [Environment]::SetEnvironmentVariable('PSModulePath',"$BuildRoot\Dependencies;$before")
    $after = [Environment]::GetEnvironmentVariable('PSModulePath')
    Write-Host "Temporarily updating Module Path to: $after"
    Write-Host "Publishing $moduleName..."

    Publish-Module -Path "$BuildRoot\Artifacts\$moduleName\" -Repository PSGallery -NuGetApiKey $APIKey -Force

    [Environment]::SetEnvironmentVariable('PSModulePath',"$before")
    Write-Host "Setting the Module Path back to: $before"
}

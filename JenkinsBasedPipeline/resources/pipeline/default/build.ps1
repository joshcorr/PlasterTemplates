param (
    $APIKey,
    $buildNumber,
    $releaseTag,
    $moduleName = "<%=$PLASTER_PARAM_ModuleName%>"
)

task . InstallSystemDependencies, Clean, Analyze, Test, UpdateVersion, Package

task InstallSystemDependenceis {
    #Probably only need this on the first build
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Install-Module Pester -Force
    Install-Module PSScriptAnalyzer -Force
    Install-Module PowerShellGet -Force
    Install-PackageProvider nuget -Force
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
    If (-not (Get-Module -Name "$moduleName")) {
        $moduleManifestFile = "$moduleName.psd1"
        Import-Module .\$moduleName\$moduleManifestFile
    }

    ### You would need to customaize this
    Invoke-Pester @someParams -Tag 'UnitTests'
}
task IntegrationTest {
    Import-Module -Name Pester -MinimumVersion 5.0
    If (-not (Get-Module -Name "$moduleName")) {
        $moduleManifestFile = "$moduleName.psd1"
        Import-Module .\$moduleName\$moduleManifestFile
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

    if (Test-Path -Path $Artifacts) {
        remove "$Artifacts/*"
    }

    New-Item -ItemType Directory -Path $Artifacts -Force
    #Just in case the module is currently loaded
    Get-Module -Name "$moduleName" | Remove-Module -Force
}
task PostClean {
    remove $BuildRoot\$moduleName, $BuildRoot\test, $BuildRoot\.git, $BuildRoot\.vscode, $BuildRoot\*.md
}
task Pacakge {
    $Artifacts = "$BuildRoot\Artifacts"
    New-Item -ItemType Directory -Path "$Artifacts" -Name "$moduleName"
    Copy-Item -Path "$BuildRoot\$moduleName\*" -Destination "$Artifacts\$moduleName\" -Recurse
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
    Publish-Module -Path "$BuildRoot\Artifacts\$moduleName\" -Repository PSGallery -NuGetApiKey $APIKey -Force
}

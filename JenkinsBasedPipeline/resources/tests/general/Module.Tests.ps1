
BeforeAll {
    $ModuleName = '<%=$PLASTER_PARAM_ModuleName%>'
    $ManifestPath = "$PSscriptRoot\$ModuleName\$ModuleName.psd1"
    $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction SilentlyContinue
}
Describe "Ensure that the module is healthy" {
    It "has a valid name" {
        $Manifest.Name | Should -Be $ModuleName
    }
    It "has a valid root module" {
        $Manifest.RootModule | Should -Be "$ModuleName.psm1"
    }
    It "has a valid Description" {
        $Manifest.Description | Should -Be '<%=$PLASTER_PARAM_Description%>'
    }
    It "has a valid Author" {
        $Manifest.Author | Should -Be '<%=$PLASTER_PARAM_Author%>'
    }
    It "has a valid Company Name" {
        $Manifest.CompanyName | Should -Be '<%=$PLASTER_PARAM_Company%>'
    }
    It "has a valid guid" {
        $Manifest.Guid | Should -Be '<%=$PLASTER_GUID1%>'
    }
}
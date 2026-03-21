#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../CpmfUipsPack.psd1') -Force
}

Describe 'Update-CpmfUipsPackProjectVersion' {

    BeforeEach {
        $script:tmpFile = New-TemporaryFile | Rename-Item -NewName { $_.Name -replace '\.tmp$', '.json' } -PassThru
    }

    AfterEach {
        Remove-Item $script:tmpFile -Force -ErrorAction SilentlyContinue
    }

    Context 'Plain release version' {
        It 'bumps minor and resets patch: 1.2.3 -> 1.3.0' {
            Set-Content $script:tmpFile '{"projectVersion": "1.2.3", "name": "MyProject"}'
            $result = Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile
            $result | Should -Be '1.3.0'
            (Get-Content $script:tmpFile -Raw) | Should -Match '"projectVersion":\s*"1\.3\.0"'
        }

        It 'handles 0.0.1 -> 0.1.0' {
            Set-Content $script:tmpFile '{"projectVersion": "0.0.1"}'
            Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile | Should -Be '0.1.0'
        }
    }

    Context 'Prerelease version' {
        It 'bumps numeric tail: 1.2.3-alpha.4 -> 1.2.3-alpha.5' {
            Set-Content $script:tmpFile '{"projectVersion": "1.2.3-alpha.4"}'
            Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile | Should -Be '1.2.3-alpha.5'
        }

        It 'appends .1 when no numeric tail: 1.2.3-alpha -> 1.2.3-alpha.1' {
            Set-Content $script:tmpFile '{"projectVersion": "1.2.3-alpha"}'
            Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile | Should -Be '1.2.3-alpha.1'
        }

        It 'handles multi-segment prerelease: 1.0.0-rc.2 -> 1.0.0-rc.3' {
            Set-Content $script:tmpFile '{"projectVersion": "1.0.0-rc.2"}'
            Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile | Should -Be '1.0.0-rc.3'
        }
    }

    Context 'Build metadata version' {
        It 'bumps numeric tail: 1.2.3+build.4 -> 1.2.3+build.5' {
            Set-Content $script:tmpFile '{"projectVersion": "1.2.3+build.4"}'
            Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile | Should -Be '1.2.3+build.5'
        }

        It 'appends .1 when no numeric tail: 1.2.3+build -> 1.2.3+build.1' {
            Set-Content $script:tmpFile '{"projectVersion": "1.2.3+build"}'
            Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile | Should -Be '1.2.3+build.1'
        }
    }

    Context '-NoBump switch' {
        It 'returns current version without modifying the file' {
            $content = '{"projectVersion": "2.0.0"}'
            # Use WriteAllText to avoid Set-Content's trailing CRLF+newline on Windows
            [System.IO.File]::WriteAllText($script:tmpFile, $content, (New-Object System.Text.UTF8Encoding $false))
            $result = Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile -NoBump
            $result | Should -Be '2.0.0'
            [System.IO.File]::ReadAllText($script:tmpFile) | Should -Be $content
        }
    }

    Context 'Error cases' {
        It 'throws when projectVersion key is missing' {
            Set-Content $script:tmpFile '{"name": "NoVersion"}'
            { Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile } | Should -Throw '*projectVersion key not found*'
        }

        It 'throws on unparseable plain version (wrong segment count)' {
            Set-Content $script:tmpFile '{"projectVersion": "1.2"}'
            { Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile } | Should -Throw '*Cannot parse version*'
        }
    }

    Context 'File encoding' {
        It 'writes UTF-8 without BOM' {
            Set-Content $script:tmpFile '{"projectVersion": "1.0.0"}'
            Update-CpmfUipsPackProjectVersion -ProjectJson $script:tmpFile | Out-Null
            $bytes = [System.IO.File]::ReadAllBytes($script:tmpFile)
            # BOM would be EF BB BF
            $bytes[0] | Should -Not -Be 0xEF
        }
    }
}

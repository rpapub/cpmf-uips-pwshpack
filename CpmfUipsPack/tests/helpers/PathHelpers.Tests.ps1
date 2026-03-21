#Requires -Version 7
#Requires -Modules Pester

# Must be loaded at script level so InModuleScope works during Pester discovery
Import-Module (Join-Path $PSScriptRoot '../../CpmfUipsPack.psd1') -Force

Describe 'Add-ToUserPath' {
    InModuleScope CpmfUipsPack {

        BeforeEach {
            $script:savedPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        }
        AfterEach {
            [Environment]::SetEnvironmentVariable('PATH', $script:savedPath, 'User')
        }

        It 'adds token when not present and returns $true' {
            [Environment]::SetEnvironmentVariable('PATH', 'C:\foo', 'User')
            $result = Add-ToUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $true
            [Environment]::GetEnvironmentVariable('PATH', 'User') | Should -BeLike '*%LOCALAPPDATA%\test\bin*'
        }

        It 'returns $false and does not duplicate when token already present' {
            [Environment]::SetEnvironmentVariable('PATH', '%LOCALAPPDATA%\test\bin;C:\foo', 'User')
            $result = Add-ToUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $false
        }

        It 'returns $false when expanded form already present' {
            $expanded = [Environment]::ExpandEnvironmentVariables('%LOCALAPPDATA%\test\bin')
            [Environment]::SetEnvironmentVariable('PATH', "$expanded;C:\foo", 'User')
            $result = Add-ToUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $false
        }

        It 'handles empty PATH' {
            [Environment]::SetEnvironmentVariable('PATH', '', 'User')
            $result = Add-ToUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $true
        }
    }
}

Describe 'Remove-FromUserPath' {
    InModuleScope CpmfUipsPack {

        BeforeEach {
            $script:savedPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        }
        AfterEach {
            [Environment]::SetEnvironmentVariable('PATH', $script:savedPath, 'User')
        }

        It 'removes token form and returns $true' {
            [Environment]::SetEnvironmentVariable('PATH', '%LOCALAPPDATA%\test\bin;C:\foo', 'User')
            $result = Remove-FromUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $true
            [Environment]::GetEnvironmentVariable('PATH', 'User') | Should -Not -BeLike '*%LOCALAPPDATA%\test\bin*'
        }

        It 'removes expanded form and returns $true' {
            $expanded = [Environment]::ExpandEnvironmentVariables('%LOCALAPPDATA%\test\bin')
            [Environment]::SetEnvironmentVariable('PATH', "$expanded;C:\foo", 'User')
            $result = Remove-FromUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $true
            [Environment]::GetEnvironmentVariable('PATH', 'User') | Should -Not -BeLike "*$expanded*"
        }

        It 'returns $false when token not present' {
            [Environment]::SetEnvironmentVariable('PATH', 'C:\foo;C:\bar', 'User')
            $result = Remove-FromUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $false
        }

        It 'returns $false on empty PATH' {
            [Environment]::SetEnvironmentVariable('PATH', '', 'User')
            $result = Remove-FromUserPath '%LOCALAPPDATA%\test\bin'
            $result | Should -Be $false
        }
    }
}

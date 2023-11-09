function Install-SteamCmd {

    <#
    .SYNOPSIS
        Download, install, and update SteamCmd.
    .DESCRIPTION
        Download, install, and update SteamCmd.
    .PARAMETER Path
        The location where SteamCmd will be installed.
    .PARAMETER Proxy
        Specifies a proxy server for the request, rather than connecting directly to the Internet resource.
    .PARAMETER ProxyCredential
        Specifies a user account that has permission to use the proxy server that's specified by the Proxy parameter.
    .NOTES
        The actual SteamCmd.exe output is in the Verbose stream. Run the Cmdlet with -Verbose to see it.
    .EXAMPLE
        Install-AsaSteamCmd

        Installs SteamCmd in the default location. The default location is "C:\Steam".
    .EXAMPLE
        Install-AsaSteamCmd -Path "C:\Program Files\SteamCmd"

        Installs SteamCmd to Program Files instead of the default location
    #>
    
    

    [CmdletBinding()]

    param (

        [ValidateNotNullOrEmpty()]
        [string]$Path = 'C:\Steam',

        [uri]$Proxy,

        [pscredential]$ProxyCredential
    )

    begin {

        $ErrorActionPreference = 'Stop'
        Set-StrictMode -Version 2

        $activity = 'Install SteamCmd'
        $tempPathGuid = [GUID]::NewGuid()
        $tempPath = Join-Path -Path $env:TEMP -ChildPath $tempPathGuid

        # If proxy is required
        $proxyArgs = @{}
        if ($Proxy) {$proxyArgs.Add('Proxy', $Proxy)}
        if ($ProxyCredential) {$proxyArgs.Add('ProxyCredential', $ProxyCredential)}

        # Are you running with an elevated Administrator token?
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdministrator) {
            $scope = 'AllUsers'
            $environmentScope = 'Machine'
        } else {
            $scope = 'CurrentUser'
            $environmentScope = 'User'
        }

        # Updating the Archive (Zip/Unzip) Module is a mandatory requirement
        Write-Progress -Activity $activity -Status 'Updating the Microsoft.PowerShell.Archive PowerShell module'
        $nugetProvider = Get-PackageProvider -Name Nuget -ListAvailable -Force
        if (-not $nugetProvider) {
            Install-PackageProvider -Name 'Nuget' -Force -Scope $scope @proxyArgs | Out-Null
        }
        Remove-Module -Name 'Microsoft.PowerShell.Archive' -Force -ErrorAction 'Ignore'
        Install-Module -Name 'Microsoft.PowerShell.Archive' -Force -Scope $scope @proxyArgs
    }

    process {

        # Ensure the Path exists
        New-Item -Path $Path -ItemType 'Directory' -Force | Out-Null

        # Ensure the tempPath exists
        New-Item -Path $tempPath -ItemType 'Directory' -Force | Out-Null

        # Download the SteamCmd Client
        Write-Progress -Activity $activity -Status 'Downloading SteamCmd'
        $steamCmdZipDownloadPath = Join-Path -Path $tempPath -ChildPath 'steamcmd.zip'
        Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -UseBasicParsing -OutFile $steamCmdZipDownloadPath @proxyArgs

        # Extract Zip file
        Write-Progress -Activity $activity -Status 'Unzipping SteamCmd'
        Expand-Archive -Path $steamCmdZipDownloadPath -DestinationPath $Path -Force

        # Add SteamCmd to PATH env variable
        if ($env:PATH -notlike "*$Path*") {

            # Set PATH Var for the system (for all future invocations)
            $currentPathEnvVar = [Environment]::GetEnvironmentVariable('PATH', $environmentScope)
            [Environment]::SetEnvironmentVariable('PATH', ($currentPathEnvVar + ";$Path"), $environmentScope)

            # Add PATH var for local process session
            $env:PATH = $env:PATH + ";$Path"
        }

        # Update SteamCmd
        Write-Progress -Activity $activity -Status 'Installing/Updating SteamCmd'
        # TODO: Figure out how to stream the output rather than letting steamcmd finish and then dumping all the output at once
        foreach ($line in $(steamcmd +quit)) {

            if ($line -like "*Error*") {
                $steamCmdError = $line -replace '^(\[.*?\]\s)?(.*)$', '$2'
                Write-Error $steamCmdError -ErrorAction Continue
            } else {
                Write-Verbose $line
            }
        }

        # Cleanup Temp Directory
        Write-Progress -Activity $activity -Completed
        Remove-Item -Path $tempPath -Force -Recurse -Confirm:$False
    }

    end {

    }
}
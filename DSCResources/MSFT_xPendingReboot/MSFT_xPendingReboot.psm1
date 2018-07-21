Function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [bool]
        $SkipCcmClientSDK
    )

    $ComponentBasedServicingKeys = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\').Name
    if ($ComponentBasedServicingKeys) {
        $ComponentBasedServicing = $ComponentBasedServicingKeys.Split("\") -contains "RebootPending"
    }
    else {
        $ComponentBasedServicing = $false
    }

    $WindowsUpdateKeys = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\').Name
    if ($WindowsUpdateKeys) {
        $WindowsUpdate = $WindowsUpdateKeys.Split("\") -contains "RebootRequired"
    }
    else {
        $WindowsUpdate = $false
    }

    $PendingFileRename = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\').PendingFileRenameOperations.Length -gt 0
    $ActiveComputerName = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName').ComputerName
    $PendingComputerName = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
    $PendingComputerRename = $ActiveComputerName -ne $PendingComputerName



    if (-not $SkipCcmClientSDK) {
        $CCMSplat = @{
            NameSpace   = 'ROOT\ccm\ClientSDK'
            Class       = 'CCM_ClientUtilities'
            Name        = 'DetermineIfRebootPending'
            ErrorAction = 'Stop'
        }

        Try {
            $CCMClientSDK = Invoke-WmiMethod @CCMSplat
        }
        Catch {
            Write-Warning "Unable to query CCM_ClientUtilities: $_"
        }
    } #CCM_ClientUtilities querey

    $SCCMSDK = ($CCMClientSDK.ReturnValue -eq 0) -and ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending)

    return @{
        Name                    = $Name
        ComponentBasedServicing = $ComponentBasedServicing
        WindowsUpdate           = $WindowsUpdate
        PendingFileRename       = $PendingFileRename
        PendingComputerRename   = $PendingComputerRename
        CcmClientSDK            = $SCCMSDK
    }
}

Function Set-TargetResource {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [bool]
        $SkipComponentBasedServicing,

        [Parameter()]
        [bool]
        $SkipWindowsUpdate,

        [Parameter()]
        [bool]
        $SkipPendingFileRename,

        [Parameter()]
        [bool]
        $SkipPendingComputerRename,

        [Parameter()]
        [bool]
        $SkipCcmClientSDK
    )
    Set-Variable -Name DSCMachineStatus -Scope Global -Value 1
}

Function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [MaintenanceWindow]
        $MaintenanceWindow,

        [Parameter()]
        [bool]
        $SkipComponentBasedServicing,

        [Parameter()]
        [bool]
        $SkipWindowsUpdate,

        [Parameter()]
        [bool]
        $SkipPendingFileRename,

        [Parameter()]
        [bool]
        $SkipPendingComputerRename,

        [Parameter()]
        [bool]
        $SkipCcmClientSDK
    )

    $status = Get-TargetResource $Name -SkipCcmClientSDK $SkipCcmClientSDK
    $Now = [datetime]::Now
    $RebootsFound = $false

    @(
        @('ComponentBasedServicing', 'Pending component based servicing reboot found.'),
        @('WindowsUpdate', 'Pending Windows Update reboot found.'),
        @('PendingFileRename', 'Pending file rename found.'),
        @('PendingComputerRename', 'Pending computer rename found.')
    ) | ForEach-Object {
        if ((-not (Get-Variable -Name ( -join ('Skip', $_[0])) -ValueOnly)) -and $Status[$_[0]]) {
            Write-Verbose $_[1]
            $RebootsFound = $true
        }
    }
    if (-not $RebootsFound) {
        Write-Verbose 'No pending reboots found.'
        $true
    }
    elseif ($MaintenanceWindow -and ( -not (
            $Now.DayOfWeek -in $MaintenanceWindow.DaysOfWeek -and
            $Now.TimeOfDay -gt $MaintenanceWindow.StartTime.TimeOfDay -and
            $Now.TimeOfDay -lt $MaintenanceWindow.EndTime.TimeOfDay
        ))) {
        Write-Verbose 'Not Within Maintenance Window - Skipping Reboot'
        $true
    }
    else {
        Write-Verbose 'Within Maintenance Window - Initiating Reboot'
        $false
    }
}

Export-ModuleMember -Function *-TargetResource

Remove-Variable -Name regRebootLocations -ErrorAction Ignore

param(
    [Parameter(Mandatory=$true)][string]$RootPath
)

$ErrorActionPreference = 'Stop'
$RootPath = $RootPath.TrimEnd('\')

# ============================================================
#  Embedded: Get-WindowsAutoPilotInfo.ps1 (Microsoft, MIT License)
#  Original author: Michael Niehaus / Microsoft
#  Wrapped as a function so this can run from a single file.
#  Logic is unchanged from the original script.
# ============================================================
function Get-WindowsAutoPilotInfoLocal
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0)][alias("DNSHostName","ComputerName","Computer")] [String[]] $Name = @("localhost"),
        [Parameter(Mandatory=$False)] [String] $OutputFile = "",
        [Parameter(Mandatory=$False)] [String] $GroupTag = "",
        [Parameter(Mandatory=$False)] [String] $AssignedUser = "",
        [Parameter(Mandatory=$False)] [Switch] $Append = $false,
        [Parameter(Mandatory=$False)] [System.Management.Automation.PSCredential] $Credential = $null,
        [Parameter(Mandatory=$False)] [Switch] $Partner = $false,
        [Parameter(Mandatory=$False)] [Switch] $Force = $false,
        [Parameter(Mandatory=$True,ParameterSetName = 'Online')] [Switch] $Online = $false,
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $TenantId = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppId = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppSecret = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AddToGroup = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AssignedComputerName = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Assign = $false,
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Reboot = $false
    )

    Begin
    {
        $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
        $computers = @()

        if ($Online) {
            $provider = Get-PackageProvider NuGet -ErrorAction Ignore
            if (-not $provider) {
                Write-Host "Installing provider NuGet"
                Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
            }

            $module = Import-Module WindowsAutopilotIntune -PassThru -ErrorAction Ignore
            if (-not $module) {
                Write-Host "Installing module WindowsAutopilotIntune"
                Install-Module WindowsAutopilotIntune -Force
            }
            Import-Module WindowsAutopilotIntune -Scope Global

            if ($AddToGroup)
            {
                $module = Import-Module AzureAD -PassThru -ErrorAction Ignore
                if (-not $module)
                {
                    Write-Host "Installing module AzureAD"
                    Install-Module AzureAD -Force
                }
            }

            if ($AppId -ne "")
            {
                $graph = Connect-MSGraphApp -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret
                Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
            }
            else {
                $graph = Connect-MSGraph
                Write-Host "Connected to Intune tenant $($graph.TenantId)"
                if ($AddToGroup)
                {
                    $aadId = Connect-AzureAD -AccountId $graph.UPN
                    Write-Host "Connected to Azure AD tenant $($aadId.TenantId)"
                }
            }

            if ($OutputFile -eq "")
            {
                $OutputFile = "$($env:TEMP)\autopilot.csv"
            }
        }
    }

    Process
    {
        foreach ($comp in $Name)
        {
            $bad = $false

            if ($comp -eq "localhost") {
                $session = New-CimSession
            }
            else
            {
                $session = New-CimSession -ComputerName $comp -Credential $Credential
            }

            Write-Verbose "Checking $comp"
            $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber

            $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
            if ($devDetail -and (-not $Force))
            {
                $hash = $devDetail.DeviceHardwareData
            }
            else
            {
                $bad = $true
                $hash = ""
            }

            if ($bad -or $Force)
            {
                $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
                $make = $cs.Manufacturer.Trim()
                $model = $cs.Model.Trim()
                if ($Partner)
                {
                    $bad = $false
                }
            }
            else
            {
                $make = ""
                $model = ""
            }

            $product = ""

            if ($Partner)
            {
                $c = New-Object psobject -Property @{
                    "Device Serial Number" = $serial
                    "Windows Product ID" = $product
                    "Hardware Hash" = $hash
                    "Manufacturer name" = $make
                    "Device model" = $model
                }
            }
            else
            {
                $c = New-Object psobject -Property @{
                    "Device Serial Number" = $serial
                    "Windows Product ID" = $product
                    "Hardware Hash" = $hash
                }

                if ($GroupTag -ne "")
                {
                    Add-Member -InputObject $c -NotePropertyName "Group Tag" -NotePropertyValue $GroupTag
                }
                if ($AssignedUser -ne "")
                {
                    Add-Member -InputObject $c -NotePropertyName "Assigned User" -NotePropertyValue $AssignedUser
                }
            }

            if ($bad)
            {
                Write-Error -Message "Unable to retrieve device hardware data (hash) from computer $comp" -Category DeviceError
            }
            elseif ($OutputFile -eq "")
            {
                $c
            }
            else
            {
                $computers += $c
            }

            Remove-CimSession $session
        }
    }

    End
    {
        if ($OutputFile -ne "")
        {
            if ($Append)
            {
                if (Test-Path $OutputFile)
                {
                    $computers += Import-CSV -Path $OutputFile
                }
            }
            if ($Partner)
            {
                $computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Manufacturer name", "Device model" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
            elseif ($AssignedUser -ne "")
            {
                $computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag", "Assigned User" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
            elseif ($GroupTag -ne "")
            {
                $computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
            else
            {
                $computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
        }
        if ($Online)
        {
            $importStart = Get-Date
            $imported = @()
            $computers | % {
                $imported += Add-AutopilotImportedDevice -serialNumber $_.'Device Serial Number' -hardwareIdentifier $_.'Hardware Hash' -groupTag $_.'Group Tag' -assignedUser $_.'Assigned User'
            }

            $processingCount = 1
            while ($processingCount -gt 0)
            {
                $current = @()
                $processingCount = 0
                $imported | % {
                    $device = Get-AutopilotImportedDevice -id $_.id
                    if ($device.state.deviceImportStatus -eq "unknown") {
                        $processingCount = $processingCount + 1
                    }
                    $current += $device
                }
                $deviceCount = $imported.Length
                Write-Host "Waiting for $processingCount of $deviceCount to be imported"
                if ($processingCount -gt 0){
                    Start-Sleep 30
                }
            }
            $importDuration = (Get-Date) - $importStart
            $importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
            Write-Host "All devices imported.  Elapsed time to complete import: $importSeconds seconds"

            $syncStart = Get-Date
            $processingCount = 1
            while ($processingCount -gt 0)
            {
                $autopilotDevices = @()
                $processingCount = 0
                $current | % {
                    $device = Get-AutopilotDevice -id $_.state.deviceRegistrationId
                    if (-not $device) {
                        $processingCount = $processingCount + 1
                    }
                    $autopilotDevices += $device
                }
                $deviceCount = $autopilotDevices.Length
                Write-Host "Waiting for $processingCount of $deviceCount to be synced"
                if ($processingCount -gt 0){
                    Start-Sleep 30
                }
            }
            $syncDuration = (Get-Date) - $syncStart
            $syncSeconds = [Math]::Ceiling($syncDuration.TotalSeconds)
            Write-Host "All devices synced.  Elapsed time to complete sync: $syncSeconds seconds"

            if ($AddToGroup)
            {
                $aadGroup = Get-AzureADGroup -Filter "DisplayName eq '$AddToGroup'"
                if ($aadGroup)
                {
                    $autopilotDevices | % {
                        $aadDevice = Get-AzureADDevice -ObjectId "deviceid_$($_.azureActiveDirectoryDeviceId)"
                        if ($aadDevice) {
                            Write-Host "Adding device $($_.serialNumber) to group $AddToGroup"
                            Add-AzureADGroupMember -ObjectId $aadGroup.ObjectId -RefObjectId $aadDevice.ObjectId
                        }
                        else {
                            Write-Error "Unable to find Azure AD device with ID $($_.azureActiveDirectoryDeviceId)"
                        }
                    }
                    Write-Host "Added devices to group '$AddToGroup' ($($aadGroup.ObjectId))"
                }
                else {
                    Write-Error "Unable to find group $AddToGroup"
                }
            }

            if ($AssignedComputerName -ne "")
            {
                $autopilotDevices | % {
                    Set-AutopilotDevice -Id $_.Id -displayName $AssignedComputerName
                }
            }

            if ($Assign)
            {
                $assignStart = Get-Date
                $processingCount = 1
                while ($processingCount -gt 0)
                {
                    $processingCount = 0
                    $autopilotDevices | % {
                        $device = Get-AutopilotDevice -id $_.id -Expand
                        if (-not ($device.deploymentProfileAssignmentStatus.StartsWith("assigned"))) {
                            $processingCount = $processingCount + 1
                        }
                    }
                    $deviceCount = $autopilotDevices.Length
                    Write-Host "Waiting for $processingCount of $deviceCount to be assigned"
                    if ($processingCount -gt 0){
                        Start-Sleep 30
                    }
                }
                $assignDuration = (Get-Date) - $assignStart
                $assignSeconds = [Math]::Ceiling($assignDuration.TotalSeconds)
                Write-Host "Profiles assigned to all devices.  Elapsed time to complete assignment: $assignSeconds seconds"
                if ($Reboot)
                {
                    Restart-Computer -Force
                }
            }
        }
    }
}

# ============================================================
#  Hash_Pro engine logic (unchanged behavior)
# ============================================================

function Sanitize {
    param([string]$Value, [switch]$KeepSpaces)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $clean = $Value.Trim() -replace '[\\/:\*\?"<>\|]', ''
    if ($KeepSpaces) {
        $clean = $clean -replace '\s+', ' '
    } else {
        $clean = $clean -replace '\s+', ''
    }
    return $clean.Trim()
}

Write-Host ""
Write-Host "========================================"
Write-Host "  AutoPilot Hash Generator (Offline)"
Write-Host "========================================"
Write-Host ""

# ---- Serial Number ----
Write-Host "[1/5] Retrieving Serial Number..."
$SN = ""
try {
    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
    $SN = Sanitize $bios.SerialNumber
} catch {
}
if ([string]::IsNullOrWhiteSpace($SN)) {
    $SN = "UnknownSN"
    Write-Host "  [WARN] Serial Number could not be read - using UnknownSN" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] Serial Number : $SN"
}

# ---- Manufacturer ----
Write-Host "[2/5] Retrieving Manufacturer..."
$MAKE = ""
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $rawMake = $cs.Manufacturer -replace '\s+(Inc\.?|Corp\.?|Corporation|Limited|Ltd\.?|Co\.?|Company).*$', ''
    $MAKE = Sanitize $rawMake
} catch {
}
if ([string]::IsNullOrWhiteSpace($MAKE)) {
    $MAKE = "UnknownBrand"
    Write-Host "  [WARN] Manufacturer could not be read - using UnknownBrand" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] Manufacturer  : $MAKE"
}

# ---- Model ----
Write-Host "[3/5] Retrieving Model Name..."
$MODEL = ""
try {
    $cs2 = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $rawModel = $cs2.Model -replace '(\D)(\d)', '$1 $2' -replace '\s+', ' '

    $brandAliases = @($MAKE, 'Hewlett-Packard', 'HP', 'Dell Inc', 'Dell', 'Lenovo', 'ASUS', 'ASUSTeK', 'Acer', 'Microsoft', 'Toshiba', 'Samsung', 'MSI') | Where-Object { $_ -and $_.Trim() -ne '' }
    foreach ($alias in ($brandAliases | Sort-Object Length -Descending)) {
        $rawModel = $rawModel -replace ('(?i)^\s*' + [regex]::Escape($alias) + '\s+'), ''
    }

    $MODEL = Sanitize $rawModel -KeepSpaces
} catch {
}
if ([string]::IsNullOrWhiteSpace($MODEL)) {
    $MODEL = "UnknownModel"
    Write-Host "  [WARN] Model could not be read - using UnknownModel" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] Model         : $MODEL"
}

# ---- Date ----
Write-Host "[4/5] Getting Current Date..."
$DT = Get-Date -Format 'dd-MM-yyyy'
Write-Host "  [OK] Date          : $DT"

# ---- Summary ----
Write-Host ""
Write-Host "========================================"
Write-Host " Device Information Summary"
Write-Host "========================================"
Write-Host " Serial Number : $SN"
Write-Host " Manufacturer  : $MAKE"
Write-Host " Model         : $MODEL"
Write-Host " Date          : $DT"
Write-Host "========================================"
Write-Host ""

# ---- Build output filename: SN-Brand-Model_Date.csv ----
$OutputName = "$SN-$MAKE-$MODEL`_$DT.csv"
$OutputFile = Join-Path $RootPath $OutputName

if (Test-Path $OutputFile) {
    $ts = Get-Date -Format 'HHmmss'
    $OutputName = "$SN-$MAKE-$MODEL`_$DT`_$ts.csv"
    $OutputFile = Join-Path $RootPath $OutputName
    Write-Host "  [WARN] File already existed - using timestamped name instead" -ForegroundColor Yellow
}

# ---- Generate the hash (offline - no -Online switch, embedded function) ----
Write-Host "[5/5] Generating AutoPilot Hash (offline mode)..."

try {
    Get-WindowsAutoPilotInfoLocal -OutputFile $OutputFile
} catch {
    Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

# ---- Validate result ----
$valid = $false
$lineCount = 0
if (Test-Path $OutputFile) {
    $lineCount = (Get-Content -Path $OutputFile | Measure-Object -Line).Lines
    if ($lineCount -gt 1) { $valid = $true }
}

Write-Host ""
if ($valid) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  SUCCESS - Hardware Hash Generated" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " File     : $OutputName"
    Write-Host " Location : $RootPath"
    Write-Host " Rows     : $lineCount (including header)"
    Write-Host "========================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ERROR - Hash Generation FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host " Possible causes:"
    Write-Host "  - TPM not present or disabled in BIOS"
    Write-Host "  - Script blocked by antivirus/policy"
    Write-Host "  - Insufficient permissions"
    Write-Host "  - PowerShell execution policy restrictions"
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}

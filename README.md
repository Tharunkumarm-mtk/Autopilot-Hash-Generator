# Windows Autopilot Hardware Hash Generator (Offline)

A lightweight, self-contained batch and PowerShell utility designed to extract Windows Autopilot hardware hashes completely offline for Microsoft Intune deployment.

## Features
- **100% Offline Execution:** Embedded `Get-WindowsAutoPilotInfo` logic eliminates the need to install PowerShell modules (`WindowsAutopilotIntune`) on target machines during OOBE.
- **Admin Elevation Check:** Automatically verifies and enforces Administrator privileges before running.
- **Clean Naming Scheme:** Generates output CSV files using the format `[Serial]-[Brand]-[Model]_[Date].csv` with automatic character sanitisation.

## Prerequisites
- Windows 10/11 Pro, Enterprise, or Education.
- Administrator access on the target machine.

## How to Use

1. **Download:** Place both `Hash_Pro.cmd` and `AutoPilotHash.ps1` into the same directory (e.g., on a USB drive).
2. **Execute:** Right-click `Hash_Pro.cmd` and select **Run as Administrator**.
3. **Upload:** Locate the generated `.csv` file in the same directory and upload it directly to **Microsoft Intune** under *Devices > Enrollment > Devices (Autopilot)*.

## File Structure
- `Hash_Pro.cmd`: Launcher batch file that verifies elevation and passes path parameters.
- `AutoPilotHash.ps1`: Engine script containing embedded Autopilot collection logic and CSV formatting.

Function fCheck-NetworkPerformance {
	<#
		.NOTES
			Author: Buchser Roger
			
		.SYNOPSIS
			Check Network Performance from Localhost to other Servers
			
		.DESCRIPTION
			This Function creates a 1 GB Dummy File and copy this File to other Servers.
			The Copy Time will be measured. Based on the measured Copy Time, the Network performance 
			will be analyzed.
			
		.PARAMETER TargetServers
			Select Servers to test Network Performance.
			
		.PARAMETER TestFileSizeGB
			Enter the Filesize in GB of the Testfile. Default is 1GB.
			
		.EXAMPLE
			fCheck-NetworkPerformance
			Measure Copy Time and Network Performance copying a 1 GB Test File to each Exchange Server.
			
		.EXAMPLE
			fCheck-NetworkPerformance -TestFileSizeGB 5
			Measure Copy Time and Network Performance copying a 5 GB Test File to each Exchange Server.
			
		.EXAMPLE
			fCheck-NetworkPerformance -TargetServers LAB-MGT-03,LAB-MGT-04
			Measure Copy Time and Network Performance copying a 1 GB Test File to Servers 'LAB-MGT-03' and 'LAB-MGT-04'
			
		.LINK
	#>
	
	PARAM (
		[Parameter(Mandatory=$True)][Array]$TargetServers,
		[Parameter(HelpMessage='Please choose not more than 10 GB')][ValidateRange(1,10)][Int]$TestFileSizeGB = 1
	) 
	
	Begin {
		If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
			Write-Host "`nError: You do not have Administrator rights to run this script!" -f Red
			Write-Host "Please restart Powershell with Administrative Privileges...`n"
			Break
		}
					
		If (!(Test-Path C:\Temp\)) {New-Item -Path C:\ -Name Temp -ItemType Directory}
		
		$TestFile = "C:\Temp\TestFile-$($TestFileSizeGB)GB-$Localhost.dummy"
		
		# Remove any existing TestFile
		Remove-Item $TestFile -ErrorAction SilentlyContinue
	
		# Create dummy File
		$TestFileSizeInBits = $TestFileSizeGB * 1073741824
		$CreateMsg = fsutil file createnew $TestFile $TestFileSizeInBits
		
		Try {
			$TotalSize = (Get-ChildItem $TestFile -ErrorAction Stop).Length
		} Catch {
			Write-Host "Unable to locate dummy file" -f Yellow
			Write-Host "Create Message: $CreateMsg" -f Yellow
			Write-Host "Last error: $($Error[0])" -f Yellow
			Exit
		}
		$RunTime = Get-Date
	}

	Process {
		Write-Host "`nMeasure Network Performance. Please wait...`n" -f Cyan
		$NetworkPerformanceOverview = @()
		ForEach ($Server in $TargetServers) {  
			Write-Host "Source Server: $Localhost | Target Server: $Server | File Size: $TestFileSizeGB GB | " -NoNewLine
			$Target = "\\$Server\c`$\Temp\"
			If (!(Test-Path $Target)) {   
				Try {
					New-Item -Path $Target -ItemType Directory -ErrorAction Stop | Out-Null
				} Catch {
					Write-Host "Problem creating $Target folder because: $($Error[0])" -f Yellow
				}
			}
			Try {
				$WriteTest = Measure-Command { 
					Copy-Item $TestFile $Target -ErrorAction Stop
				}
				$WriteMBs = [Math]::Round(($TotalSize/$WriteTest.TotalSeconds)/1048576,0)
			} Catch {
				Write-Host "Problem during speed test: $($Error[0])" -f Yellow
				$Status = "$($Error[0])"
				$WriteMBs = 0
				$WriteTest = New-TimeSpan -Days 0
			}
			Write-Host "Copy Time: $([Math]::Round($WriteTest.TotalSeconds,1)) sec`t| Measured Value: $([Math]::Round($WriteMBs,0)) MB/s"
			$Obj = New-Object PsObject
			$Obj | Add-Member -Membertype NoteProperty -Name SourceServer -Value $Localhost
			$Obj | Add-Member -Membertype NoteProperty -Name TargetServer -Value $Server
			$Obj | Add-Member -Membertype NoteProperty -Name CopyTime -Value "$([Math]::Round($WriteTest.TotalSeconds,1)) Seconds"
			$Obj | Add-Member -Membertype NoteProperty -Name NetworkPerformance -Value "$([Math]::Round($WriteMBs,0)) MB/s"
			$NetworkPerformanceOverview += $Obj
			Remove-Item "$Target\TestFile-$($TestFileSizeGB)GB-$Localhost.dummy" -ErrorAction SilentlyContinue
		}
	}

	End {
		Remove-Item $TestFile -ErrorAction SilentlyContinue
		$Result = ($NetworkPerformanceOverview | Sort TargetServer | ft @{E="SourceServer";N="Source Server       ";Width=20},@{E="TargetServer";N="Target Server       ";Width=20},@{E="CopyTime";N="      Copy Time";Align='Right';Width=15},@{E="NetworkPerformance";N=" Network Performance";Align='Right';Width=20} | Out-String).Trim()
		Write-Host $Result
		[String]$Date = ((Get-Date).Date).ToString("yyyy-MM-dd")
		$NetworkPerformanceOverview | Export-Csv -Path "$Logs\$Date - Network Performance Check.csv" -Delimiter ";" -Encoding UTF8 -NoTypeInformation
	}
}

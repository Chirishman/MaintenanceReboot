Class MaintenanceWindow {
    [Bool]$Enabled = $true
    [DateTime]$StartTime
    [DateTime]$EndTime
    [System.DayOfWeek[]]$DaysOfWeek = @([System.DayOfWeek]::Saturday, [System.DayOfWeek]::Sunday)
    [ValidateSet('Weekly', 'Daily')][string]$Frequency

    MaintenanceWindow ([DateTime]$StartTime, [DateTime]$EndTime, [String]$Frequency) {
        $this.StartTime = $StartTime
        $this.EndTime = $EndTime
        $this.Frequency = $Frequency

        if ( $Frequency -eq 'Daily' ) {
            $this.DaysOfWeek = ([system.dayofweek].DeclaredMembers.Name | Where-Object {$_ -notmatch '_'})
        }
    }

    MaintenanceWindow ([DateTime]$StartTime, [DateTime]$EndTime, [String]$Frequency, [System.DayOfWeek[]]$DaysOfWeek) {
        $this.StartTime = $StartTime
        $this.EndTime = $EndTime
        $this.DaysOfWeek = $DaysOfWeek
        $this.Frequency = $Frequency
    }
	MaintenanceWindow ([MaintenanceWindow]$MaintenanceWindow) {
        $this.Enabled = $MaintenanceWindow.Enabled
		$this.StartTime = $MaintenanceWindow.StartTime
        $this.EndTime = $MaintenanceWindow.EndTime
        $this.DaysOfWeek = $MaintenanceWindow.DaysOfWeek
        $this.Frequency = $MaintenanceWindow.Frequency
    }
	MaintenanceWindow ([String]$JSON) {
        $ParsedJSON = $JSON | ConvertFrom-Json
		$this.Enabled = $ParsedJSON.Enabled
		$this.StartTime = $ParsedJSON.StartTime
        $this.EndTime = $ParsedJSON.EndTime
        $this.DaysOfWeek = $ParsedJSON.DaysOfWeek
        $this.Frequency = $ParsedJSON.Frequency
    }

	[String]ToString() {
		return "$($this | ConvertTo-Json -Compress)"
	}
}
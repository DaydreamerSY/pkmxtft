# Role audit (docs/ROLES.md): N headless Godot workers probe the ability of every form (tools/roles/role_probe.tscn)
# at below-normal priority, no window, no sound; then tools/roles/role_audit.py writes the report.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/role_audit.ps1 [-Workers 6] [-Only MOLTRES,ZAPDOS]
#     [-ReportOnly]        (-ReportOnly: no probe, the report again from build/roles/probe_*.tsv, e.g. after editing
#                           tools/roles/role_rules.json)
param(
	[int]$Workers = 0,
	[string]$Only = "",
	[string]$Out = "build/roles",
	[switch]$ReportOnly,
	[string]$Godot = "C:\Users\nqloc\godot-android\Godot_v4.7-stable_win64_console.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ($Workers -le 0) { $Workers = [Math]::Max(1, [Environment]::ProcessorCount - 2) }
$outDir = if ([IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $root $Out }
New-Item -ItemType Directory -Force $outDir | Out-Null
if (-not $ReportOnly) {
	Get-ChildItem $outDir -Filter "probe_*.tsv" | Remove-Item -Force
	if ($Only) { $Workers = 1 }
	$started = Get-Date
	$procs = @()
	for ($w = 0; $w -lt $Workers; $w++) {
		$a = @("--headless", "--path", "`"$root`"", "res://tools/roles/role_probe.tscn", "--", "out=`"$outDir`"",
			"shard=$w/$Workers")
		if ($Only) { $a += "only=$Only" }
		$p = Start-Process -FilePath $Godot -ArgumentList $a -NoNewWindow -PassThru `
			-RedirectStandardOutput (Join-Path $outDir "log_$w.txt") -RedirectStandardError (Join-Path $outDir "err_$w.txt")
		try { $p.PriorityClass = "BelowNormal" } catch {}
		$procs += $p
	}
	Write-Host "role probe: $Workers workers -> $outDir"
	$procs | Wait-Process
	Write-Host "role probe: done in $([int]((Get-Date) - $started).TotalSeconds) s"
}
python (Join-Path $root "tools/roles/role_audit.py") $outDir

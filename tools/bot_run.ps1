# Bot batch: N headless Godot workers playing Endless runs (tools/bot/bot_runner.tscn) at below-normal
# priority, no window, no sound; then the report (tools/bot/report.py). See docs/BOT.md.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/bot_run.ps1 -Runs 500 -Workers 6 -Out build/bot/b1 `
#     -Diffs normal,hard -Seasons s1,s2,s3 -Passes journey -Report
# -Runs: runs per worker. -Workers 0: the logical cores minus 2. -NoUnits: no units_*.tsv (smaller).
param(
	[int]$Runs = 200,
	[int]$Workers = 0,
	[string]$Out = "build/bot/latest",
	[string]$Diffs = "",
	[string]$Seasons = "",
	[string]$Passes = "",
	[string]$Styles = "",
	[int]$Seed = 0,
	[switch]$NoUnits,
	[switch]$Report,
	[string]$Knowledge = "tools/bot/knowledge.json",
	[string]$Model = "tools/bot/model.json",
	[switch]$Design,
	[int]$Combo = 2,
	[switch]$NoLearn,
	[string]$Godot = "C:\Users\nqloc\godot-android\Godot_v4.7-stable_win64_console.exe"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ($Workers -le 0) { $Workers = [Math]::Max(1, [Environment]::ProcessorCount - 2) }
if ($Seed -le 0) { $Seed = Get-Random -Minimum 1 -Maximum 1000000000 }
$outDir = if ([IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $root $Out }
New-Item -ItemType Directory -Force $outDir | Out-Null
$knowPath = if ([IO.Path]::IsPathRooted($Knowledge)) { $Knowledge } else { Join-Path $root $Knowledge }
$modelPath = if ([IO.Path]::IsPathRooted($Model)) { $Model } else { Join-Path $root $Model }
if ($Design) { $Styles = "design" }
$started = Get-Date
$procs = @()
for ($w = 0; $w -lt $Workers; $w++) {
	$a = @("--headless", "--path", "`"$root`"", "res://tools/bot/bot_runner.tscn", "--", "runs=$Runs",
		"seed=$($Seed + $w * 1000003)", "out=`"$outDir`"", "worker=$w", "knowledge=`"$knowPath`"", "model=`"$modelPath`"", "workers=$Workers", "combo=$Combo")
	if ($Diffs) { $a += "diffs=$Diffs" }
	if ($Seasons) { $a += "seasons=$Seasons" }
	if ($Passes) { $a += "passes=$Passes" }
	if ($Styles) { $a += "styles=$Styles" }
	if ($NoUnits) { $a += "units=0" }
	$p = Start-Process -FilePath $Godot -ArgumentList $a -NoNewWindow -PassThru `
		-RedirectStandardOutput (Join-Path $outDir "log_$w.txt") -RedirectStandardError (Join-Path $outDir "err_$w.txt")
	try { $p.PriorityClass = "BelowNormal" } catch {}
	$procs += $p
}
Write-Host "bot: $Workers workers x $Runs runs -> $outDir (seed $Seed)"
$procs | Wait-Process
$secs = [int]((Get-Date) - $started).TotalSeconds
$errors = 0
foreach ($w in 0..($Workers - 1)) {
	$meta = Join-Path $outDir "meta_$w.tsv"
	if (Test-Path $meta) {
		$line = Select-String -Path $meta -Pattern "^errors`t" | Select-Object -First 1
		if ($line) { $errors += [int]($line.Line.Split("`t")[1]) }
	}
}
Write-Host "bot: done in $secs s, $errors run(s) stopped by a script error"
# what the workers learned goes into the knowledge file (the next batch starts from it)
if (-not $NoLearn) {
	python (Join-Path $root "tools/bot/learn.py") $outDir --into $knowPath
	python (Join-Path $root "tools/bot/train_model.py") --all --out $modelPath # the model learns every batch so far
}
if ($Report) { python (Join-Path $root "tools/bot/report.py") $outDir }

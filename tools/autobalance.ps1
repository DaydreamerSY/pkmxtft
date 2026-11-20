# Auto balance loop (docs/BOT.md "Tự cân bằng"): N times { a bot batch played with the balance in use
# (tools/bot_run.ps1: headless workers, below normal priority, no window, no sound) -> tools/bot/autobalance.py
# (one step of data/balance.json - every Pokémon's own stats, PP included, by the criteria of
# tools/bot/balance_targets.json - from that batch only; its report: <batch>/balance_report.txt) -> the pro bot's model
# learns again }.
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/autobalance.ps1 -Iterations 3 -Runs 300 -Workers 12
# Batches go to <Out>_v<version> (build/bot/bal_v1, bal_v2...). -Dry: one batch, the step printed, nothing written.
param(
	[int]$Iterations = 3,
	[int]$Runs = 300, # per worker: 12 x 300 = 3 600 runs a step (1 200 runs: the deviations of a form are half noise)
	[int]$Workers = 0,
	[string]$Out = "build/bot/bal",
	[string]$Styles = "pro,synergy",
	[string]$Seasons = "s1,s2,s3,all",
	[string]$Diffs = "normal",
	[double]$Rate = 0.5, # damping of the steps (1 = the full step the data asks for)
	[int]$Min = 60,
	[double]$Explore = 0.03,
	[switch]$Dry
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$py = Join-Path $root "tools/bot"
for ($i = 1; $i -le $Iterations; $i++) {
	$version = (Get-Content (Join-Path $root "data/balance.json") -Raw | ConvertFrom-Json).version
	$dir = "$($Out)_v$version"
	Write-Host "autobalance: step $i / $Iterations, balance version $version -> $dir"
	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "bot_run.ps1") -Runs $Runs `
		-Workers $Workers -Out $dir -Diffs $Diffs -Seasons $Seasons -Passes all -Styles $Styles -NoLearn
	$a = @((Join-Path $py "autobalance.py"), (Join-Path $root $dir), "--rate", $Rate, "--min", $Min, "--explore", $Explore)
	if ($Dry) { $a += "--dry" }
	python @a
	if ($Dry) { break }
	python (Join-Path $py "train_model.py") --all # the pro bot learns the new numbers
}

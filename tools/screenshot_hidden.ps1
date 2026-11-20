# Chụp ảnh màn hình game (tests/screenshot.tscn, cần cửa sổ thật) mà KHÔNG làm phiền người đang dùng máy:
# Godot chạy trên một desktop ẩn của Windows, nên cửa sổ không hiện lên, không lấy focus, không nhận / di
# chuyển chuột; âm thanh tắt (--audio-driver Dummy). Log của Godot ghi vào <thư mục>\godot.log.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\screenshot_hidden.ps1 <thư mục> [menu|synergy|vfx ...] [lang=vi] [pass=5]
#   tools\screenshot_hidden.bat <thư mục> [...]
#
# Biến môi trường: GODOT (exe Godot 4.7, bản không console), SHOT_TIMEOUT (giây, mặc định 240), SHOT_ENGINE_ARGS
# (tham số thêm cho Godot, vd "--fixed-fps 50" cho chế độ motion),
# SHOT_RESOLUTION (vd 1600x738 = tỉ lệ điện thoại 19.5:9; kèm `ui_scale=2 touch insets=60,0 cutout=0,246,60,48`
# để xem bố cục mobile đúng như máy thử: hệ số ×2,0, lỗ camera ở mép trái).
# Scene khác: SHOT_SCENE=res://... (các tham số sau thư mục được chuyển nguyên cho scene sau "--").
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Out,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

$godot = $env:GODOT
if (-not $godot) { $godot = "C:\Users\nqloc\godot-android\Godot_v4.7-stable_win64.exe" }
$timeout = 240
if ($env:SHOT_TIMEOUT) { $timeout = [int]$env:SHOT_TIMEOUT }
$scene = $env:SHOT_SCENE
if (-not $scene) { $scene = "res://tests/screenshot.tscn" }
$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Out = [System.IO.Path]::GetFullPath($Out)
New-Item -ItemType Directory -Force $Out | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class HiddenDesktop
{
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateDesktopW(string lpszDesktop, IntPtr lpszDevice, IntPtr pDevmode, int dwFlags, uint dwDesiredAccess, IntPtr lpsa);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool CloseDesktop(IntPtr hDesktop);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO
    {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION
    {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);

    [DllImport("kernel32.dll")]
    static extern uint WaitForSingleObject(IntPtr h, uint ms);

    [DllImport("kernel32.dll")]
    static extern bool TerminateProcess(IntPtr h, uint code);

    [DllImport("kernel32.dll")]
    static extern bool GetExitCodeProcess(IntPtr h, out uint code);

    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr h);

    // Exit code of the program; -1000 - error: no desktop; -2000 - error: not started; 9999: killed after the timeout.
    public static int Run(string desktop, string commandLine, string cwd, uint timeoutMs)
    {
        IntPtr d = CreateDesktopW(desktop, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000, IntPtr.Zero);
        if (d == IntPtr.Zero)
            return -1000 - Marshal.GetLastWin32Error();
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        si.lpDesktop = desktop;
        PROCESS_INFORMATION pi;
        if (!CreateProcessW(null, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, cwd, ref si, out pi))
        {
            int e = Marshal.GetLastWin32Error();
            CloseDesktop(d);
            return -2000 - e;
        }
        uint code = 0;
        if (WaitForSingleObject(pi.hProcess, timeoutMs) != 0)
        {
            TerminateProcess(pi.hProcess, 9999);
            WaitForSingleObject(pi.hProcess, 5000);
            code = 9999;
        }
        else
        {
            GetExitCodeProcess(pi.hProcess, out code);
        }
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        CloseDesktop(d);
        return (int)code;
    }
}
"@

$scene_args = ""
if ($Rest) { $scene_args = " " + ($Rest -join " ") }
$resolution = ""
if ($env:SHOT_RESOLUTION) { $resolution = " --resolution " + $env:SHOT_RESOLUTION }
# thêm tham số cho Godot, vd SHOT_ENGINE_ARGS="--fixed-fps 50" (chế độ motion: mỗi frame đúng 1/50 s thời gian game)
if ($env:SHOT_ENGINE_ARGS) { $resolution += " " + $env:SHOT_ENGINE_ARGS }
$command = '"' + $godot + '" --path "' + $project + '" --audio-driver Dummy' + $resolution + ' --log-file "' + (Join-Path $Out "godot.log") +
    '" ' + $scene + ' -- "' + $Out + '"' + $scene_args
$code = [HiddenDesktop]::Run("pkmxtft_hidden_shots", $command, $project, [uint32]($timeout * 1000))
Write-Output "exit code: $code$(if ($code -eq 9999) { ' (timeout: killed)' })"
Get-ChildItem $Out -Filter *.png | ForEach-Object { Write-Output $_.FullName }
exit $code

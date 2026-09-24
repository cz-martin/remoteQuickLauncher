# Název skriptu běžícího na pozadí
$workerScriptName = "remote.ps1"

# Najdeme procesy PowerShellu a zkusíme najít ten náš podle příkazové řádky
$runningProcess = Get-CimInstance Win32_Process -Filter "Name LIKE '%powershell%'" | 
    Where-Object { $_.CommandLine -like "*$workerScriptName*" }

if ($runningProcess) {
    # Získání objektu procesu a jeho WindowHandle
    $proc = Get-Process -Id $runningProcess.ProcessId -ErrorAction SilentlyContinue
    if ($proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
        
        # Přidáme si Win32 API helper pro vytažení do popředí
        Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32Foreground {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool SetForegroundWindow(IntPtr hWnd);
                
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            }
"@
        # 9 = SW_RESTORE (obnoví z minimalizovaného stavu)
        [Win32Foreground]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
        # Vynucení popředí
        [Win32Foreground]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    }
} else {
    # Pokud ještě neběží, spustíme ho skrytě
    $workerPath = Join-Path $PSScriptRoot $workerScriptName
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-WindowStyle",
        "Hidden",
        "-File",
        $workerPath
    ) -WindowStyle Hidden | Out-Null
}
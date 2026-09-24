$pidFile = Join-Path $PSScriptRoot "remote.pid"
$PID | Out-File $pidFile -Force

# Zajistíme, že při zavření okna se PID soubor smaže
Register-EngineEvent PowerShell.Exiting -Action {
    if (Test-Path $global:pidFile) { Remove-Item $global:pidFile -ErrorAction SilentlyContinue }
} | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeMethods {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$consoleHandle = [NativeMethods]::GetConsoleWindow()
if ($consoleHandle -ne [IntPtr]::Zero) {
    if ([NativeMethods]::IsWindowVisible($consoleHandle)) {
        $workerPath = if ($PSVersionTable.PSVersion.Major -ge 3) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
        Start-Process -FilePath "powershell.exe" -ArgumentList 
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", $workerPath 
            -WorkingDirectory $PSScriptRoot -WindowStyle Hidden | Out-Null
        exit
    }
    else {
        [NativeMethods]::ShowWindow($consoleHandle, 0) | Out-Null
    }
}

# --- URČENÍ KOŘENOVÉ SLOŽKY SKRIPTU ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# --- FUNKCE PRO NAČTENÍ INI SOUBORU ---
function Get-IniContent ($filePath) {
    $ini = @{}
    if (Test-Path $filePath) {
        Get-Content $filePath -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*;' -and $_ -notmatch '^\s*$' } | ForEach-Object {
            if ($_ -match '^\s*\[(?<section>.*)\]\s*$') {
                $section = $matches['section'].Trim()
                if (-not $ini.ContainsKey($section)) { $ini[$section] = @{} }
            }
            elseif ($_ -match '^\s*(?<key>[^=]+)\s*=\s*(?<value>.*)\s*$') {
                if ($section) {
                    $val = $matches['value'].Trim().Trim('"').Trim("'")
                    $ini[$section][$matches['key'].Trim()] = $val
                }
            }
        }
    }
    return $ini
}

# --- NAČTENÍ KONFIGURACE Z INI ---
$iniPath = Join-Path $scriptDir "config.ini"
$configIni = Get-IniContent $iniPath

$vncPath = if ($configIni['Paths'] -and $configIni['Paths']['vncPath']) { $configIni['Paths']['vncPath'] }     else { "C:\Program Files\UltraVNC\vncviewer.exe" }
$rdpPath = if ($configIni['Paths'] -and $configIni['Paths']['rdpPath']) { $configIni['Paths']['rdpPath'] }     else { "$env:SystemRoot\system32\mstsc.exe" }
$puttyPath = if ($configIni['Paths'] -and $configIni['Paths']['puttyPath']) { $configIni['Paths']['puttyPath'] }   else { "C:\Program Files\PuTTY\putty.exe" }
$browserPath = if ($configIni['Paths'] -and $configIni['Paths']['browserPath']) { $configIni['Paths']['browserPath'] } else { "" }

$jsonFileName = if ($configIni['Paths'] -and $configIni['Paths']['jsonPath']) { $configIni['Paths']['jsonPath'] } else { "devices.json" }
$jsonPath = if ([System.IO.Path]::IsPathRooted($jsonFileName)) { $jsonFileName } else { Join-Path $scriptDir $jsonFileName }

if (Test-Path $jsonPath) {
    $devices = Get-Content $jsonPath -Encoding UTF8 | ConvertFrom-Json
}
else {
    $devices = @()
    [System.Windows.Forms.MessageBox]::Show("POZOR: Soubor s daty nebyl nalezen na ceste:`n$jsonPath", "Chyba", "OK", "Warning")
}

# Globální paměť pro uchování objektů zařízení
$global:filteredDevices = @()

# --- POMOCNÁ FUNKCE: GENEROVÁNÍ PNG VLAJEČEK ---
function Get-FlagImage ($country) {
    $bmp = New-Object System.Drawing.Bitmap(18, 12)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    
    if ($country -eq "CZ") {
        $g.Clear([System.Drawing.Color]::White)
        $redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 20, 26))
        $blueBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(17, 69, 126))
        $g.FillRectangle($redBrush, 0, 6, 18, 6)
        $p1 = New-Object System.Drawing.Point(0, 0); $p2 = New-Object System.Drawing.Point(9, 6); $p3 = New-Object System.Drawing.Point(0, 12)
        $g.FillPolygon($blueBrush, [System.Drawing.Point[]]@($p1, $p2, $p3))
    }
    elseif ($country -eq "EN") {
        $redBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 16, 46))
        $whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
        $g.Clear([System.Drawing.Color]::FromArgb(1, 33, 105))
        $g.DrawLine($whitePen, 0, 0, 18, 12); $g.DrawLine($whitePen, 0, 12, 18, 0)
        $g.FillRectangle([System.Drawing.Brushes]::White, 7, 0, 4, 12); $g.FillRectangle([System.Drawing.Brushes]::White, 0, 4, 18, 4)
        $g.FillRectangle($redBrush, 8, 0, 2, 12); $g.FillRectangle($redBrush, 0, 5, 18, 2)
    }
    $g.Dispose()
    return $bmp
}

$imgCZ = Get-FlagImage "CZ"
$imgEN = Get-FlagImage "EN"

# --- JAZYKY & BARVY ---
$global:lang = "EN"
$dict = @{
    "CZ" = @{ "Title" = "Remote Quick Launcher"; "Search" = "Vyhledat lokalitu nebo IP:"; "Status" = "Enter = Pripojit | Sipky = Navigace"; "Found" = "Nalezeno polozek: {0} | Enter = Pripojit"; "NotFound" = "Zadanemu vyrazu nic neodpovidal."; "Launch" = "Spoustim {0} pro {1}:{2}..."; "NoPuTTY" = "Nenalezena aplikace PuTTY na ceste:`n{0}" }
    "EN" = @{ "Title" = "Remote Quick Launcher"; "Search" = "Search location or IP:"; "Status" = "Enter = Connect | Arrows = Navigation"; "Found" = "Found items: {0} | Enter = Connect"; "NotFound" = "No matching items found."; "Launch" = "Launching {0} for {1}:{2}..."; "NoPuTTY" = "PuTTY application not found at path:`n{0}" }
}

$bgColor = [System.Drawing.Color]::FromArgb(32, 33, 36)
$cardColor = [System.Drawing.Color]::FromArgb(48, 49, 52)
$textColor = [System.Drawing.Color]::FromArgb(241, 243, 244)
$subTextColor = [System.Drawing.Color]::FromArgb(154, 160, 166)
$accentColor = [System.Drawing.Color]::FromArgb(138, 180, 248)
$selectionBg = [System.Drawing.Color]::FromArgb(60, 64, 67)

# FONT PRO IKONY WINDOWS
$iconFont = New-Object System.Drawing.Font("Segoe MDL2 Assets", 10)
$textFont = New-Object System.Drawing.Font("Segoe UI", 10)

# --- OKNO & PRVKY ---
$form = New-Object System.Windows.Forms.Form
$form.Text = $dict[$global:lang]["Title"]; $form.Width = 460; $form.Height = 560; $form.BackColor = $bgColor; $form.ForeColor = $textColor; $form.FormBorderStyle = "FixedSingle"; $form.MaximizeBox = $false; $form.StartPosition = "CenterScreen"; $form.TopMost = $true; $form.Padding = New-Object System.Windows.Forms.Padding(15)

$picSearch = New-Object System.Windows.Forms.Label
$picSearch.Text = [char]0xE721
$picSearch.Font = New-Object System.Drawing.Font("Segoe MDL2 Assets", 9)
$picSearch.Location = New-Object System.Drawing.Point(15, 13); $picSearch.Size = New-Object System.Drawing.Size(16, 16); $picSearch.ForeColor = $subTextColor

$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = $dict[$global:lang]["Search"]; $lblSearch.Location = New-Object System.Drawing.Point(34, 12); $lblSearch.AutoSize = $true; $lblSearch.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold); $lblSearch.ForeColor = $subTextColor

$btnCZ = New-Object System.Windows.Forms.Button
$btnCZ.Text = "  CZ"; $btnCZ.Image = $imgCZ; $btnCZ.ImageAlign = "MiddleLeft"; $btnCZ.Size = New-Object System.Drawing.Size(65, 24); $btnCZ.Location = New-Object System.Drawing.Point(298, 8); $btnCZ.FlatStyle = "Flat"; $btnCZ.FlatAppearance.BorderSize = 0; $btnCZ.BackColor = if ($global:lang -eq "CZ") { $accentColor } else { $cardColor }; $btnCZ.ForeColor = if ($global:lang -eq "CZ") { [System.Drawing.Color]::Black } else { $textColor }; $btnCZ.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)

$btnEN = New-Object System.Windows.Forms.Button
$btnEN.Text = "  EN"; $btnEN.Image = $imgEN; $btnEN.ImageAlign = "MiddleLeft"; $btnEN.Size = New-Object System.Drawing.Size(65, 24); $btnEN.Location = New-Object System.Drawing.Point(368, 8); $btnEN.FlatStyle = "Flat"; $btnEN.FlatAppearance.BorderSize = 0; $btnEN.BackColor = if ($global:lang -eq "EN") { $accentColor } else { $cardColor }; $btnEN.ForeColor = if ($global:lang -eq "EN") { [System.Drawing.Color]::Black } else { $textColor }; $btnEN.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = New-Object System.Drawing.Point(15, 35); $txtSearch.Width = 414; $txtSearch.Height = 35; $txtSearch.Font = New-Object System.Drawing.Font("Segoe UI", 11); $txtSearch.BackColor = $cardColor; $txtSearch.ForeColor = $textColor; $txtSearch.BorderStyle = "FixedSingle"

# --- CHECKBOXY S TEXTEM ---
$chkFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$chkVNC = New-Object System.Windows.Forms.CheckBox; $chkVNC.Text = "VNC"; $chkVNC.Checked = $true; $chkVNC.AutoSize = $true; $chkVNC.Location = New-Object System.Drawing.Point(15, 75); $chkVNC.Font = $chkFont; $chkVNC.ForeColor = $textColor
$chkRDP = New-Object System.Windows.Forms.CheckBox; $chkRDP.Text = "RDP"; $chkRDP.Checked = $true; $chkRDP.AutoSize = $true; $chkRDP.Location = New-Object System.Drawing.Point(95, 75); $chkRDP.Font = $chkFont; $chkRDP.ForeColor = $textColor
$chkSSH = New-Object System.Windows.Forms.CheckBox; $chkSSH.Text = "SSH"; $chkSSH.Checked = $true; $chkSSH.AutoSize = $true; $chkSSH.Location = New-Object System.Drawing.Point(175, 75); $chkSSH.Font = $chkFont; $chkSSH.ForeColor = $textColor
$chkWEB = New-Object System.Windows.Forms.CheckBox; $chkWEB.Text = "HTTP/S"; $chkWEB.Checked = $true; $chkWEB.AutoSize = $true; $chkWEB.Location = New-Object System.Drawing.Point(255, 75); $chkWEB.Font = $chkFont; $chkWEB.ForeColor = $textColor

# --- VLASTNÍ VYKRESLOVANÝ LISTBOX PRO IKONY ---
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(15, 110); $listBox.Width = 414; $listBox.Height = 340
$listBox.BackColor = $cardColor; $listBox.ForeColor = $textColor; $listBox.BorderStyle = "None"
$listBox.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$listBox.ItemHeight = 26

# VYKRRESLOVACÍ LOGIKA PRO KAŽDÝ ŘÁDEK
$listBox.Add_DrawItem({
        param($sender, $e)
        if ($e.Index -lt 0 -or $e.Index -ge $global:filteredDevices.Count) { return }

        $dev = $global:filteredDevices[$e.Index]
        $isSelected = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -eq [System.Windows.Forms.DrawItemState]::Selected

        # Pozadí
        $bg = if ($isSelected) { $selectionBg } else { $cardColor }
        $brushBg = New-Object System.Drawing.SolidBrush($bg)
        $e.Graphics.FillRectangle($brushBg, $e.Bounds)

        # Výběr ikony podle protokolu (kódy Segoe MDL2 Assets)
        $iconChar = switch ($dev.calcProto) {
            "RDP" { [char]0xE7F4 } # Monitor
            "SSH" { if ($dev.key) { [char]0xE88D } else { [char]0xE9E9 } } # Zámek nebo kabel
            "HTTP" { [char]0xE774 } # Web
            "HTTPS" { [char]0xE774 } # Web
            default { [char]0xE975 } # VNC / Obrazovka
        }

        # Barva ikonky
        $iconColor = if ($isSelected) { $accentColor } else { $subTextColor }
        $brushIcon = New-Object System.Drawing.SolidBrush($iconColor)
        $brushText = New-Object System.Drawing.SolidBrush($textColor)

        # 1. Nakreslení IKONY
        $e.Graphics.DrawString([string]$iconChar, $iconFont, $brushIcon, ($e.Bounds.X + 5), ($e.Bounds.Y + 4))

        # 2. Nakreslení TEXTU
        $displayText = "$($dev.name)  -  $($dev.ip):$($dev.calcPort)"
        $e.Graphics.DrawString($displayText, $textFont, $brushText, ($e.Bounds.X + 28), ($e.Bounds.Y + 3))

        $brushBg.Dispose()
        $brushIcon.Dispose()
        $brushText.Dispose()
    })

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = $dict[$global:lang]["Status"]; $lblStatus.Location = New-Object System.Drawing.Point(15, 470); $lblStatus.Size = New-Object System.Drawing.Size(414, 25); $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8.5); $lblStatus.ForeColor = $subTextColor; $lblStatus.TextAlign = "MiddleCenter"

# --- LOGIKA FILTROVÁNÍ ---
$filterAction = {
    $query = $txtSearch.Text.Trim()
    $listBox.Items.Clear()
    $global:filteredDevices = @()
    
    foreach ($dev in $devices) {
        if ($dev.name -like "*$query*" -or $dev.ip -like "*$query*") {
            $proto = if ($dev.protocol) { $dev.protocol.ToUpper() } else { "VNC" }
            $isWeb = ($proto -eq "HTTP" -or $proto -eq "HTTPS")
            
            if (($proto -eq "VNC" -and $chkVNC.Checked) -or
                ($proto -eq "RDP" -and $chkRDP.Checked) -or
                ($proto -eq "SSH" -and $chkSSH.Checked) -or
                ($isWeb -and $chkWEB.Checked)) {
                
                $port = if ($dev.port) { $dev.port } else {
                    switch ($proto) {
                        "RDP" { 3389 }
                        "SSH" { 22 }
                        "HTTP" { 80 }
                        "HTTPS" { 443 }
                        default { 5900 }
                    }
                }
                
                $devCopy = $dev | Select-Object *, @{N = 'calcPort'; E = { $port } }, @{N = 'calcProto'; E = { $proto } }
                $global:filteredDevices += $devCopy
                
                # Vložíme dummy položku jen aby ListBox věděl, kolik má řádků
                [void]$listBox.Items.Add("")
            }
        }
    }
    
    if ($listBox.Items.Count -gt 0) {
        $lblStatus.Text = $dict[$global:lang]["Found"] -f $listBox.Items.Count
    }
    else {
        $lblStatus.Text = $dict[$global:lang]["NotFound"]
    }
}

$switchLanguage = {
    param($newLang)
    $global:lang = $newLang
    $form.Text = $dict[$global:lang]["Title"]
    $lblSearch.Text = $dict[$global:lang]["Search"]
    if ($global:lang -eq "CZ") {
        $btnCZ.BackColor = $accentColor; $btnCZ.ForeColor = [System.Drawing.Color]::Black
        $btnEN.BackColor = $cardColor; $btnEN.ForeColor = $textColor
    }
    else {
        $btnEN.BackColor = $accentColor; $btnEN.ForeColor = [System.Drawing.Color]::Black
        $btnCZ.BackColor = $cardColor; $btnCZ.ForeColor = $textColor
    }
    &$filterAction
}

$connectAction = {
    if ($listBox.SelectedIndex -ne -1) {
        $dev = $global:filteredDevices[$listBox.SelectedIndex]
        $proto = $dev.calcProto
        $ip = $dev.ip
        $port = $dev.calcPort
        
        $lblStatus.Text = $dict[$global:lang]["Launch"] -f $proto, $ip, $port
        $lblStatus.ForeColor = $accentColor
        
        if ($proto -eq "RDP") {
            if ($port -eq 3389) { Start-Process -FilePath $rdpPath -ArgumentList "/v:$ip" }
            else { Start-Process -FilePath $rdpPath -ArgumentList "/v:${ip}:${port}" }
        }
        elseif ($proto -eq "VNC") {
            & $vncPath "$ip`::$port"
        }
        elseif ($proto -eq "SSH") {
            if (Test-Path $puttyPath) {
                if ($dev.key) {
                    $keyPath = $dev.key
                    Start-Process -FilePath $puttyPath -ArgumentList "-ssh $ip -P $port -i `"$keyPath`""
                }
                else {
                    Start-Process -FilePath $puttyPath -ArgumentList "-ssh $ip -P $port"
                }
            }
            else {
                $msg = $dict[$global:lang]["NoPuTTY"] -f $puttyPath
                [System.Windows.Forms.MessageBox]::Show($msg, "Error", "OK", "Error")
            }
        }
        elseif ($proto -eq "HTTP" -or $proto -eq "HTTPS") {
            $scheme = $proto.ToLower()
            if (($scheme -eq "http" -and $port -eq 80) -or ($scheme -eq "https" -and $port -eq 443)) {
                $url = "${scheme}://${ip}"
            }
            else {
                $url = "${scheme}://${ip}:${port}"
            }

            if ($browserPath -and (Test-Path $browserPath)) {
                Start-Process -FilePath $browserPath -ArgumentList $url
            }
            else {
                Start-Process $url
            }
        }
    }
}

# --- EVENTY ---
$btnCZ.Add_Click({ &$switchLanguage "CZ" })
$btnEN.Add_Click({ &$switchLanguage "EN" })
$txtSearch.Add_TextChanged($filterAction)
$txtSearch.Add_Click({ 
        # Pokud uživatel klikne do textboxu myší, označíme celý text pro pohodlné přepsání
        $txtSearch.SelectAll() 
    })
$chkVNC.Add_CheckedChanged($filterAction)
$chkRDP.Add_CheckedChanged($filterAction)
$chkSSH.Add_CheckedChanged($filterAction)
$chkWEB.Add_CheckedChanged($filterAction)

$txtSearch.Add_KeyDown({
        if ($_.KeyCode -eq 'Enter' -and $listBox.Items.Count -gt 0) {
            $listBox.SelectedIndex = 0
            &$connectAction
        }
        elseif ($_.KeyCode -eq 'Down' -and $listBox.Items.Count -gt 0) {
            $listBox.Focus()
            $listBox.SelectedIndex = 0
        }
    })

$listBox.Add_DoubleClick($connectAction)
$listBox.Add_KeyDown({
        if ($_.KeyCode -eq 'Enter') { &$connectAction }
        elseif ($_.KeyCode -eq 'Escape') { $txtSearch.Focus(); $txtSearch.SelectAll() }
    })

&$filterAction

$form.Controls.Add($picSearch)
$form.Controls.Add($lblSearch)
$form.Controls.Add($btnCZ)
$form.Controls.Add($btnEN)
$form.Controls.Add($txtSearch)
$form.Controls.Add($chkVNC)
$form.Controls.Add($chkRDP)
$form.Controls.Add($chkSSH)
$form.Controls.Add($chkWEB)
$form.Controls.Add($listBox)
$form.Controls.Add($lblStatus)

# --- AKTIVACE A OZNÁMENÍ TEXTU PŘI ZOBRAZENÍ / FOCUSU ---
$form.Add_Shown({ 
        $form.Activate()
        $txtSearch.Focus()
        $txtSearch.SelectAll() 
    })

$form.Add_Activated({
        $txtSearch.Focus()
        $txtSearch.SelectAll()
    })

$form.ShowDialog() | Out-Null
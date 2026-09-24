*Read this in other languages: [Čeština](README.cz.md)*

# Remote Quick Launcher (VNC / RDP / SSH / Web)

![Language](https://img.shields.io/badge/Language-PowerShell-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A fast, lightweight, and efficient remote connection launcher with a dark graphical user interface (GUI) for Windows. This tool allows instant search and launch for **VNC**, **RDP**, **SSH (PuTTY)**, and **HTTP/HTTPS** web interfaces from a single organized application.

![Remote Quick Launcher Icon](remote.ico) *(Application Icon)*

---

## 🚀 Key Features

* **Instant Search:** Real-time filtering by device name or IP address.
* **Multi-Protocol Support:** Supports RDP, VNC, SSH, and HTTP/HTTPS with easy checkbox filtering.
* **Dual Language Interface:** Switch instantly between Czech and English (CZ / EN).
* **Dark Theme:** Modern dark UI built on `System.Windows.Forms`.
* **Clean Launch (No Console Window):** Background script invocation hides the PowerShell console window for a smooth user experience.
* **Dynamic Configuration:** Manage all devices and connection details via an external JSON file.

---

## 🛠️ Requirements

* **OS:** Windows 10 / 11
* **PowerShell:** Version 5.1 or newer
* **Clients (Optional, based on usage):**
  * **RDP:** Built-in Windows `mstsc.exe`
  * **VNC:** UltraVNC Viewer (or custom path in configuration)
  * **SSH:** PuTTY

---

## 📁 File Structure

```text
├── RemoteLauncher.ps1   # Main GUI application script
├── run.vbs              # VBScript for hidden execution without console window
├── restore.ps1          # Helper script to bring active instance to foreground
├── config.ini           # Executable paths and JSON data file settings
├── devices.json         # Database of devices and IP addresses
└── remote.ico           # Application icon
```

---

## ⚙️ Configuration

### 1. Client Paths (`config.ini`)
Define application paths and your device database file in `config.ini`:

```ini
[Paths]
vncPath=C:\Program Files\UltraVNC\vncviewer.exe
rdpPath=C:\Windows\system32\mstsc.exe
puttyPath=C:\Program Files\PuTTY\putty.exe
jsonPath=devices.json
```
*(If left blank, default system paths will be used where applicable)*.

### 2. Device Management (`devices.json`)
Add your remote endpoints to `devices.json` using the following schema:

```json
[
  {
    "name": "Workstation-VNC",
    "ip": "192.168.1.20",
    "protocol": "VNC",
    "port": 5900
  },
  {
    "name": "Main-Server",
    "ip": "192.168.1.10",
    "protocol": "RDP",
    "port": 3389
  },
  {
    "name": "Mikrotik-Router",
    "ip": "192.168.1.1",
    "protocol": "SSH",
    "port": 22,
    "key": "C:\\Keys\\id_rsa.ppk"
  },
  {
    "name": "NAS-Storage",
    "ip": "192.168.1.50",
    "protocol": "HTTPS",
    "port": 5001
  }
]
```

---

## 🖥️ How to Run

1. **Direct Launch:** Double-click `run.vbs`. The GUI will open cleanly without displaying any black terminal window.
2. **Launch via PowerShell:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   .\RemoteLauncher.ps1
   ```

---

## 💡 Controls & Shortcuts

* **`ENTER Key` in search field:** Immediately connects to the first matched device in the list.
* **`Down Arrow`:** Shifts focus down into the results list.
* **`Double Click`:** Connects to the selected device.
* **`ESC Key`:** Resets focus to the search field and selects all text.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

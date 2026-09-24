*Přečtěte si tento dokument v jiném jazyce: [English](README.md)*

# Remote Quick Launcher (VNC / RDP / SSH / Web)

![Language](https://img.shields.io/badge/Language-PowerShell-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

Rychlý, lehký a efektivní spouštěč vzdálených připojení s tmavým grafickým rozhraním (GUI) v systémech Windows. Nástroj umožňuje okamžité vyhledávání a spouštění relací **VNC**, **RDP**, **SSH (PuTTY)** a **HTTP/HTTPS** webových rozhraní z jednoho přehledného místa.

![Remote Quick Launcher Icon](remote.ico) *(Ikona aplikace)*

---

## 🚀 Hlavní funkce

* **Rychlé vyhledávání:** Filtrování podle názvu zařízení nebo IP adresy v reálném čase.
* **Podpora více protokolů:** Podpora pro RDP, VNC, SSH a HTTP/HTTPS s možností filtrování pomocí checkboxů.
* **Dvojjazyčné rozhraní:** Okamžité přepínání mezi českým a anglickým jazykem (CZ / EN).
* **Tmavý režim (Dark Theme):** Moderní grafické rozhraní postavené na `System.Windows.Forms` přizpůsobené pro temné prostředí.
* **Spuštění bez viditelného okna konzole:** Skripty na pozadí skrývají konzolové okno PowerShellu pro čistý uživatelský zážitek.
* **Dynamické načítání ze souboru JSON:** Všechna zařízení a jejich parametry jsou spravována v jednom externím konfigurátoru.

---

## 🛠️ Požadavky

* **OS:** Windows 10 / 11
* **PowerShell:** Verze 5.1 nebo novější
* **Klienti (volitelné dle využití):**
  * **RDP:** Integrovaný `mstsc.exe` ve Windows
  * **VNC:** UltraVNC Viewer (nebo jiný dle cesty v konfiguračním souboru)
  * **SSH:** PuTTY

---

## 📁 Struktura souborů

```text
├── RemoteLauncher.ps1   # Hlavní skript aplikace s GUI a logikou
├── run.vbs              # VBScript pro skryté spuštění bez konzolového okna
├── restore.ps1          # Pomocný skript pro vytažení již běžící aplikace do popředí
├── config.ini           # Cesty k jednotlivým spouštěcím aplikacím
├── devices.json         # Databáze zařízení a IP adres
└── remote.ico           # Ikona aplikace
```

---

## ⚙️ Konfigurace

### 1. Cesty k aplikacím (`config.ini`)
V souboru `config.ini` definujte cesty ke svým klientům a datovému souboru:

```ini
[Paths]
vncPath=C:\Program Files\UltraVNC\vncviewer.exe
rdpPath=C:\Windows\system32\mstsc.exe
puttyPath=C:\Program Files\PuTTY\putty.exe
jsonPath=devices.json
```
*(Pokud cesty v `config.ini` nevyplníte, skript automaticky použije výchozí cestu z Windows)*.

### 2. Správa zařízení (`devices.json`)
Zařízení přidávejte do souboru `devices.json` v následujícím formátu:

```json
[
  {
    "name": "Pracovni-Stanice-VNC",
    "ip": "192.168.1.20",
    "protocol": "VNC",
    "port": 5900
  },
  {
    "name": "Server-Hlavni",
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
    "name": "Web-NAS",
    "ip": "192.168.1.50",
    "protocol": "HTTPS",
    "port": 5001
  }
]
```

---

## 🖥️ Jak aplikaci spustit

1. **Přímé spuštění:** Spusťte soubor `run.vbs` dvoklikem. Aplikace se otevře bez jakéhokoliv probliknutí černého konzolového okna.
2. **Spuštění z PowerShellu:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   .\RemoteLauncher.ps1
   ```

---

## 💡 Ovládání

* **`Klávesa ENTER` w/ vyhledávač:** Rychle připojí první nalezené zařízení v seznamu.
* **`Šipka dolů`:** Přepne fokus do seznamu výsledků.
* **`Dvojklik`:** Spustí spojení na vybrané zařízení.
* **`ESC`:** Vrátí fokus zpět do vyhledávacího pole a označí text.

---

## 📄 Licencování

Tento projekt je poskytován pod licencí [MIT](LICENSE). Máte plnou svobodu k jeho úpravám a šíření.

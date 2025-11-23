<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>📱 UltraOS Web Toolkit</title>
    <link rel="stylesheet" href="assets/style.css">
</head>
<body>
    <header>
        <h1>📱 UltraOS Web Toolkit</h1>
        <p>Vítejte v hlavním ovládacím panelu pro vaše Android zařízení.</p>
    </header>

    <main>
        <section class="device-status">
            <h2>Stav zařízení</h2>
            <p id="device-model">Model: Načítám...</p>
            <p id="device-android">Android: Načítám...</p>
            <p id="device-serial">Serial: Načítám...</p>
            <button onclick="refreshDeviceStatus()">Obnovit stav</button>
        </section>

        <section class="actions">
            <h2>Akce</h2>

            <div class="action-card">
                <h3>🔓 FRP/OEM Bypass</h3>
                <p>Spusťte automatický bypass FRP nebo OEM zámku.</p>
                <form action="api/frp.php" method="POST">
                    <button type="submit">Spustit FRP Bypass</button>
                </form>
            </div>

            <div class="action-card">
                <h3>📦 Instalace APK</h3>
                <p>Nahrajte a nainstalujte APK soubor na zařízení.</p>
                <form action="api/install_apk.php" method="POST" enctype="multipart/form-data">
                    <input type="file" name="apkfile" accept=".apk">
                    <button type="submit">Instalovat APK</button>
                </form>
            </div>

            <div class="action-card">
                <h3>🔄 Restart zařízení</h3>
                <p>Restartujte zařízení do různých režimů.</p>
                <form action="api/reboot.php" method="POST">
                    <select name="mode">
                        <option value="system">Systém</option>
                        <option value="recovery">Recovery</option>
                        <option value="bootloader">Bootloader</option>
                        <option value="sideload">Sideload (Recovery)</option>
                    </select>
                    <button type="submit">Restartovat</button>
                </form>
            </div>

            <div class="action-card">
                <h3>📝 Live Logcat</h3>
                <p>Zobrazte výstup logcatu ze zařízení v reálném čase.</p>
                <pre id="logcat-output" style="max-height: 200px; overflow-y: scroll; background: #333; color: #0f0; padding: 10px; border-radius: 5px;"></pre>
                <button onclick="toggleLogcat()">Start/Stop Logcat</button>
            </div>
            
            </section>
    </main>

    <script src="assets/ajax.js"></script>
    <script>
        // Inicializace při načtení stránky
        document.addEventListener('DOMContentLoaded', () => {
            refreshDeviceStatus();
            // Start logcat automaticky po načtení stránky, pokud chceš
            // toggleLogcat(); 
        });
    </script>
</body>
</html>
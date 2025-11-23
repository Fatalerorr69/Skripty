<<<<<<< HEAD
// --- JavaScript pro AJAX komunikaci webového GUI ---

// Funkce pro získání stavu zařízení
function refreshDeviceStatus() {
    fetch('api/status.php')
        .then(response => response.json())
        .then(data => {
            document.getElementById('device-model').innerText = 'Model: ' + (data.model || 'N/A');
            document.getElementById('device-android').innerText = 'Android: ' + (data.android_version || 'N/A');
            document.getElementById('device-serial').innerText = 'Serial: ' + (data.serial || 'N/A');
        })
        .catch(error => console.error('Chyba při načítání stavu zařízení:', error));
}

// Proměnná pro ukládání stavu logcatu
let logcatInterval;
let isLogcatRunning = false;

// Funkce pro spuštění/zastavení logcatu
function toggleLogcat() {
    const logcatOutput = document.getElementById('logcat-output');
    if (isLogcatRunning) {
        clearInterval(logcatInterval);
        logcatOutput.innerText += "\n--- Logcat zastaven ---";
        isLogcatRunning = false;
    } else {
        logcatOutput.innerText = "--- Spouštím Logcat ---\n";
        logcatInterval = setInterval(() => {
            fetch('api/logcat.php')
                .then(response => response.text())
                .then(data => {
                    logcatOutput.innerText = data; // Přepíše celým logem
                    logcatOutput.scrollTop = logcatOutput.scrollHeight; // Scroll dolů
                })
                .catch(error => console.error('Chyba při načítání logcatu:', error));
        }, 1000); // Obnovuje každou sekundu
        isLogcatRunning = true;
    }
}

// Zde budou další AJAX funkce pro formuláře (FRP, Flash, Reboot atd.)
=======
// --- JavaScript pro AJAX komunikaci webového GUI ---

// Funkce pro získání stavu zařízení
function refreshDeviceStatus() {
    fetch('api/status.php')
        .then(response => response.json())
        .then(data => {
            document.getElementById('device-model').innerText = 'Model: ' + (data.model || 'N/A');
            document.getElementById('device-android').innerText = 'Android: ' + (data.android_version || 'N/A');
            document.getElementById('device-serial').innerText = 'Serial: ' + (data.serial || 'N/A');
        })
        .catch(error => console.error('Chyba při načítání stavu zařízení:', error));
}

// Proměnná pro ukládání stavu logcatu
let logcatInterval;
let isLogcatRunning = false;

// Funkce pro spuštění/zastavení logcatu
function toggleLogcat() {
    const logcatOutput = document.getElementById('logcat-output');
    if (isLogcatRunning) {
        clearInterval(logcatInterval);
        logcatOutput.innerText += "\n--- Logcat zastaven ---";
        isLogcatRunning = false;
    } else {
        logcatOutput.innerText = "--- Spouštím Logcat ---\n";
        logcatInterval = setInterval(() => {
            fetch('api/logcat.php')
                .then(response => response.text())
                .then(data => {
                    logcatOutput.innerText = data; // Přepíše celým logem
                    logcatOutput.scrollTop = logcatOutput.scrollHeight; // Scroll dolů
                })
                .catch(error => console.error('Chyba při načítání logcatu:', error));
        }, 1000); // Obnovuje každou sekundu
        isLogcatRunning = true;
    }
}

// Zde budou další AJAX funkce pro formuláře (FRP, Flash, Reboot atd.)
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
// Můžeš je přidávat sem nebo do samostatných funkcí
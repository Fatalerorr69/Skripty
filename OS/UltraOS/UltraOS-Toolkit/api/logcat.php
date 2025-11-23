<?php
// --- WebUI API: Live Logcat Stream ---
header('Content-Type: text/plain');

$serial = null;
// Získání sériového čísla aktivního zařízení (zjednodušeno pro jeden aktivní)
$output = shell_exec('/usr/bin/adb devices | grep -w "device" | awk \'{print $1}\'');
$lines = explode("\n", $output);
foreach ($lines as $line) {
    if (!empty(trim($line))) {
        $serial = trim($line);
        break;
    }
}

if ($serial) {
    // Spuštění adb logcat pro aktuálně připojené zařízení
    // Limit na posledních 100 řádků pro menší zátěž
    // Cesta k adb musí být správná
    $logcat_output = shell_exec('/usr/bin/adb -s ' . escapeshellarg($serial) . ' logcat -t 100');
    echo $logcat_output;
} else {
    echo "Žádné zařízení není připojeno nebo logcat není dostupný.";
}
?>
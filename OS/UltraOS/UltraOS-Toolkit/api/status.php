<?php
// --- WebUI API: Získání stavu zařízení ---
header('Content-Type: application/json');

// Spuštění ADB příkazu
$output = shell_exec('/usr/bin/adb devices -l'); // Použij celou cestu k adb, nebo zajisti PATH
$lines = explode("\n", $output);

$device_info = [
    'model' => null,
    'android_version' => null,
    'serial' => null,
    'status' => 'offline'
];

foreach ($lines as $line) {
    if (strpos($line, 'device') !== false && strpos($line, 'product:') !== false) {
        preg_match('/^(.*)\s+device\s+product:([^\s]+)\s+model:([^\s]+)\s+device:([^\s]+)/', $line, $matches);
        if (isset($matches[1])) {
            $device_info['serial'] = trim($matches[1]);
            $device_info['status'] = 'online';

            // Získání modelu a verze Androidu přes adb shell
            $model_raw = shell_exec('/usr/bin/adb -s ' . escapeshellarg($device_info['serial']) . ' shell getprop ro.product.model');
            $android_ver_raw = shell_exec('/usr/bin/adb -s ' . escapeshellarg($device_info['serial']) . ' shell getprop ro.build.version.release');

            $device_info['model'] = trim($model_raw);
            $device_info['android_version'] = trim($android_ver_raw);
            break; // Předpokládáme jedno aktivní zařízení
        }
    }
}

echo json_encode($device_info);
?>
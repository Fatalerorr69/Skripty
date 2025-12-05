android_info() { adb devices -l; }
android_flash() { fastboot flash "$@"; }
android_backup() { adb backup -apk -shared -all -f ~/backup.ab; }

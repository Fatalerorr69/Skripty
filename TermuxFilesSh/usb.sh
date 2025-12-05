usb_list() { lsblk -o NAME,SIZE,TYPE,MOUNTPOINT; }
usb_detect() { termux-usb -l 2>/dev/null || echo "[]"; }
usb_mount() { mkdir -p /data/data/com.termux/files/usr/usb; mount -o rw "$1" /data/data/com.termux/files/usr/usb || echo "Mount failed"; }

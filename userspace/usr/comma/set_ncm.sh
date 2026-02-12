#!/bin/bash
set -euo pipefail

USB_IF="usb0"
USB_ADDR="192.168.42.2/24"
UDC_NAME="a600000.usb"

setup() {
  sudo modprobe libcomposite 2>/dev/null || true

  if ! mountpoint -q /config; then
    sudo mount -t configfs none /config
  else
    echo "/config is already mounted."
  fi

  sudo mkdir -p /config/usb_gadget/g1
  cd /config/usb_gadget/g1

  if [ -f UDC ] && [ -n "$(cat UDC 2>/dev/null || true)" ]; then
    echo "" | sudo tee UDC >/dev/null || true
    sleep 0.2
  fi

  sudo mkdir -p strings/0x409
  sudo mkdir -p configs/c.1/strings/0x409
  sudo mkdir -p functions/ncm.0

  echo 0x04D8 | sudo tee idVendor
  echo 0x1234 | sudo tee idProduct

  echo "$(cat /proc/cmdline | sed -e 's/^.*androidboot.serialno=//' -e 's/ .*$//')" | sudo tee strings/0x409/serialnumber
  echo "comma.ai" | sudo tee strings/0x409/manufacturer
  echo "comma four" | sudo tee strings/0x409/product
  echo 250 | sudo tee configs/c.1/MaxPower

  echo "NCM" | sudo tee configs/c.1/strings/0x409/configuration

  sudo rm -f configs/c.1/ncm.0
  sudo ln -s functions/ncm.0 configs/c.1/
}

start() {
  cd /config/usb_gadget/g1

  CUR="$(cat UDC 2>/dev/null || true)"
  if [ -n "$CUR" ]; then
    echo "" | sudo tee UDC >/dev/null || true
    sleep 0.2
  fi

  echo "$UDC_NAME" | sudo tee UDC

  for i in $(seq 1 30); do
    if ip link show "$USB_IF" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if ! ip link show "$USB_IF" >/dev/null 2>&1; then
    echo "WARNING: $USB_IF not present yet (host may not be connected)."
    return 0
  fi

  sudo ip link set "$USB_IF" up

  if ! ip addr show dev "$USB_IF" | grep -q "192.168.42.2/24"; then
    ip addr show dev "$USB_IF" | awk '/192\.168\.42\./ {print $2}' | while read -r cidr; do
      sudo ip addr del "$cidr" dev "$USB_IF" || true
    done
    sudo ip addr add "$USB_ADDR" dev "$USB_IF"
  fi

  sudo systemctl restart dnsmasq
}

stop() {
  if [ -d "/config/usb_gadget/g1" ]; then
    cd /config/usb_gadget/g1
    echo "" | sudo tee UDC >/dev/null || true
  fi

  if ip link show "$USB_IF" >/dev/null 2>&1; then
    sudo ip link set "$USB_IF" down || true
  fi
}

USB_NCM_PARAM="/data/params/d/UsbNcmEnabled"
if [ -f "$USB_NCM_PARAM" ] && [ "$(< $USB_NCM_PARAM)" == "1" ]; then
  echo "Enabling USB NCM + DHCP"
  setup
  start
else
  echo "Disabling USB NCM + DHCP"
  stop
fi
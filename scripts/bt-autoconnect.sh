# Connect every paired Bluetooth device.
#
# BlueZ never initiates the *first* connection -- its [Policy] reconnect only
# fires after a link is lost -- so without this you would right-click Connect in
# blueman every time. Shared by two units:
#   * usrs/mods/bluetooth: a user service at login (WirePlumber must be up for
#     an A2DP connection to stick, hence user rather than system);
#   * sys/mods/core/bluetooth: a system hook on wake from suspend (the user
#     manager exposes no sleep.target of its own).
#
# @bluetoothctl@ is substituted at build time.

btctl=@bluetoothctl@

# bluetoothd -- and after hibernate the USB dongle itself -- need a moment.
for _ in $(seq 1 40); do
  "$btctl" show >/dev/null 2>&1 && break
  sleep 0.5
done

# The controller can come back powered off after a hibernate resume.
"$btctl" power on >/dev/null 2>&1 || true
sleep 2

# Retry: right after a resume the first page often fails with
# br-connection-unknown while the earbuds finish waking up.
for _ in $(seq 1 6); do
  pending=0
  for mac in $("$btctl" devices Paired | cut -d' ' -f2); do
    "$btctl" info "$mac" | grep -q 'Connected: yes' && continue
    timeout 5 "$btctl" connect "$mac" >/dev/null 2>&1 || true
    "$btctl" info "$mac" | grep -q 'Connected: yes' || pending=1
  done
  [ "$pending" = 0 ] && break
  sleep 2
done

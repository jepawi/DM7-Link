"""This computer's network adapters, by name, and the one SuperRack talks to.

SuperRack's ProLink controller asks for two things: a PORT (one of ITS computer's adapters,
which must be wired) and a CONSOLE IP (the address of the computer running DM7 Link). Here the
engineer picks the adapter by the name the system gives it -- "USB 10/100/1000 LAN",
"Ethernet 2" -- and the page shows that adapter's one address to type in.

The choice is kept by NAME, not by address: a DHCP lease that changes the address changes what
the page shows, not which adapter was chosen. The rack bridge itself keeps listening on every
adapter, so nothing has to be re-opened when the address moves -- and SuperRack on this same
Mac can still use 127.0.0.1.

Names come from `psutil` (Windows: the friendly name, "Ethernet 2"); on macOS the BSD name
(en7) is turned into the hardware port name with `networksetup`. Without psutil the addresses
are still listed, unnamed.
"""
from __future__ import annotations

import subprocess
import sys

from PySide6.QtCore import Property, QObject, Signal, Slot

WIRELESS = ("wi-fi", "wifi", "wlan", "wireless", "airport", "802.11")
SKIP_PREFIX = ("127.", "169.254.", "0.")


def _mac_ports() -> dict:
    """en7 -> ("USB 10/100/1000 LAN", "00:11:22:33:44:55") (macOS only). The hardware address
    comes from here because psutil on macOS hands back a placeholder (02:00:00:00:00:00)."""
    if sys.platform != "darwin":
        return {}
    try:
        out = subprocess.run(["networksetup", "-listallhardwareports"], capture_output=True,
                             text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    ports, port, device = {}, "", ""
    for line in out.splitlines():
        if line.startswith("Hardware Port:"):
            port, device = line.split(":", 1)[1].strip(), ""
        elif line.startswith("Device:") and port:
            device = line.split(":", 1)[1].strip()
            ports[device] = (port, "")
        elif line.startswith("Ethernet Address:") and device:
            ports[device] = (port, line.split(":", 1)[1].strip().lower())
    return ports


def adapters() -> list[dict]:
    """[{name, device, ip, wireless}] for every adapter that is up with an IPv4 address."""
    try:
        import psutil
    except ImportError:
        psutil = None
    if psutil is None:
        from rackbridge.netinfo import local_addresses
        return [{"name": ip, "device": ip, "ip": ip, "mac": "", "wireless": False}
                for ip in local_addresses()]
    try:
        addrs, stats = psutil.net_if_addrs(), psutil.net_if_stats()
    except Exception:            # noqa: BLE001
        return []
    mac = _mac_ports()
    link = getattr(psutil, "AF_LINK", None)
    out = []
    for device, entries in addrs.items():
        st = stats.get(device)
        if st is not None and not st.isup:
            continue
        hw = mac.get(device, ("", ""))[1] or next(
            (str(a.address).lower().replace("-", ":") for a in entries
             if link is not None and a.family == link and a.address), "")
        for a in entries:
            if getattr(a.family, "name", str(a.family)) != "AF_INET" and a.family != 2:
                continue
            if str(a.address).startswith(SKIP_PREFIX):
                continue
            name = mac.get(device, (device, ""))[0] or device
            out.append({"name": name, "device": device, "ip": str(a.address), "mac": hw,
                        "wireless": any(w in name.lower() for w in WIRELESS)})
    out.sort(key=lambda d: (d["wireless"], d["name"].lower()))
    return out


class AdapterChoice(QObject):
    """The adapter SuperRack's ProLink Port is on, and its address -- for the Setup page."""

    changed = Signal()

    def __init__(self, config, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.config = config
        self._list: list = adapters()

    def _chosen_name(self) -> str:
        return str(self.config.get("superrack_adapter", "") or "")

    def _chosen(self) -> dict | None:
        want = self._chosen_name()
        hit = next((a for a in self._list if a["device"] == want), None)
        if hit is None and not want:
            # Nothing chosen yet: the first wired adapter, else whatever there is.
            hit = next((a for a in self._list if not a["wireless"]), None) or \
                  (self._list[0] if self._list else None)
        return hit

    @Slot()
    def rescan(self) -> None:
        self._list = adapters()
        self.changed.emit()

    @Slot(str)
    def choose(self, device: str) -> None:
        self.config.set("superrack_adapter", str(device))
        self.config.save()
        self.changed.emit()

    def _rows(self) -> list:
        return [{"label": a["name"], "raw": a["device"],
                 "hint": a["ip"] + ("  ·  Wi-Fi" if a["wireless"] else "")} for a in self._list]

    items = Property("QVariantList", lambda self: self._rows(), notify=changed)
    name = Property(str, lambda self: (self._chosen() or {}).get("name", ""), notify=changed)
    device = Property(str, lambda self: (self._chosen() or {}).get("device", ""), notify=changed)
    ip = Property(str, lambda self: (self._chosen() or {}).get("ip", ""), notify=changed)
    wireless = Property(bool, lambda self: bool((self._chosen() or {}).get("wireless")),
                        notify=changed)
    # The adapter as SuperRack's ProLink PORT list writes it: "00:11:22:33:44:55 - en7 -"
    # on a Mac. On Windows the list shows the adapter's own name.
    portText = Property(str, lambda self: (lambda a: (
        f"{a['mac']} - {a['device']} -" if a.get("mac") and sys.platform == "darwin"
        else a.get("name", "")) if a else "")(self._chosen()), notify=changed)
    missing = Property(bool, lambda self: bool(self._chosen_name()) and self._chosen() is None,
                       notify=changed)
    missingName = Property(str, lambda self: self._chosen_name(), notify=changed)

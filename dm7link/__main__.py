"""DM7 Link -- start the app.

    python3 run.py                       connect to the console last used
    python3 run.py 192.168.0.2           ...or to this one
    python3 run.py --demo                no console: a recorded one stands in
    python3 run.py --ltc-bench 01:00:00:00   timecode generated in the app, no interface
    python3 run.py --screenshot out --page waves --shot-at 2500

What is built here, and nothing else:

    console     SessionWorker + ConnectionController   the DM7 link, discovery, reconnect
    scenes      SceneBridge                             the scene list and the one recall door
    waves       WavesBridge, link "direct"              the rack bridge runs in this app;
                                                        SuperRack's ProLink dials this computer
    timecode    ltc.Reader + ShowCues                   an audio interface, scene cues
"""
from __future__ import annotations

import argparse
import signal
import sys

from . import paths

paths.install()

from PySide6.QtCore import Property, QObject, Qt, QTimer, QUrl, Signal, Slot  # noqa: E402
from PySide6.QtGui import QDesktopServices, QFontDatabase, QGuiApplication, QIcon  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401

from dm7gui.channels import ChannelsBridge  # noqa: E402
from dm7gui.connection import ConnectionController  # noqa: E402
from dm7gui.controls import ControlsBridge  # noqa: E402
from dm7gui.ltc import Reader as LtcReader  # noqa: E402
from dm7gui.metering import MeterBridge  # noqa: E402
from dm7gui.scenes import SceneBridge  # noqa: E402
from dm7gui.session import SessionWorker  # noqa: E402
from dm7gui.waves import WavesBridge  # noqa: E402

from . import __version__  # noqa: E402
from .adapters import AdapterChoice  # noqa: E402
from .appconfig import AppConfig  # noqa: E402
from .features import AppMacros, Features  # noqa: E402
from .timecode import ShowCues  # noqa: E402

PAGES = ("console", "waves", "timecode", "macros", "settings")


class SelKeyRelay(QObject):
    """A desk SEL key, from the change pump's thread to the UI thread."""
    key = Signal(str, int, bool)


class App(QObject):
    """What the window needs that belongs to no engine: the page, the version, the clipboard."""

    pageChanged = Signal()

    def __init__(self, page: str = "console", data_dir: str = "") -> None:
        super().__init__()
        self._page = page if page in PAGES else "console"
        self._data = data_dir

    @Slot(str)
    def setPage(self, page: str) -> None:
        if page in PAGES and page != self._page:
            self._page = page
            self.pageChanged.emit()

    @Slot(str)
    def copy(self, text: str) -> None:
        QGuiApplication.clipboard().setText(str(text))

    @Slot()
    def openDataFolder(self) -> None:
        QDesktopServices.openUrl(QUrl.fromLocalFile(self._data))

    page = Property(str, lambda self: self._page, notify=pageChanged)
    version = Property(str, lambda self: __version__, constant=True)
    dataDir = Property(str, lambda self: self._data, constant=True)
    platform = Property(str, lambda self: sys.platform, constant=True)


def _args(argv) -> argparse.Namespace:
    ap = argparse.ArgumentParser(prog="dm7-link", description="DM7 show control")
    ap.add_argument("ip", nargs="?", help="console address")
    ap.add_argument("--demo", action="store_true", help="a recorded console instead of a desk")
    ap.add_argument("--demo-settings", default=None, help="demo: which capture to replay")
    ap.add_argument("--no-auto-connect", action="store_true")
    ap.add_argument("--page", choices=PAGES, default=None)
    ap.add_argument("--section", default=None, help="screenshots: the Waves tab to open on")
    ap.add_argument("--size", default="1440x900")
    ap.add_argument("--ltc-bench", default=None, metavar="TC",
                    help="generate timecode from TC inside the app (no interface)")
    ap.add_argument("--screenshot", default=None, metavar="PREFIX")
    ap.add_argument("--shot-at", default="2500")
    ap.add_argument("--selftest", action="store_true", help="load the UI, hold 2.5 s, exit")
    return ap.parse_args(argv)


def _fonts() -> None:
    folder = paths.resource("fonts")
    for f in sorted(folder.glob("*.ttf")):
        QFontDatabase.addApplicationFont(str(f))


def main(argv=None) -> int:
    args = _args(sys.argv[1:] if argv is None else argv)
    QGuiApplication.setApplicationName(paths.APP_NAME)
    QGuiApplication.setOrganizationName(paths.APP_NAME)
    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    app = QGuiApplication(sys.argv[:1])
    _fonts()
    icon = paths.resource("icon.png")
    if icon.exists():
        app.setWindowIcon(QIcon(str(icon)))

    data = paths.data_dir()
    data.mkdir(parents=True, exist_ok=True)
    config = AppConfig(data / "config.json")
    if args.ip:
        config.set("console_ip", args.ip)
    if args.no_auto_connect:
        config.set("auto_connect", False)
    # The rack bridge always runs inside this app: SuperRack connects here.
    waves_cfg = dict(config.get("waves", {}) or {})
    # ...and Touch & Turn is not part of this app: no desk fader drives SuperRack.
    if waves_cfg.get("link") != "direct" or waves_cfg.get("send_tnt", True) or waves_cfg.get("tnt_fader"):
        waves_cfg.update(link="direct", send_tnt=False, tnt_fader="")
        config.set("waves", waves_cfg)
    ltc_cfg = dict(config.get("ltc", {}) or {})
    if ltc_cfg.get("input") != "audio":
        ltc_cfg["input"] = "audio"
        if ltc_cfg.get("device") in (None, "", "auto") or "CARD" in str(ltc_cfg.get("device")):
            ltc_cfg["device"] = "auto"
        config.set("ltc", ltc_cfg)
    config.save()

    if args.ltc_bench:
        from dm7gui.ltc import BenchEdges, bench_edges
        BenchEdges.start_at = args.ltc_bench
        LtcReader.audio_factory = staticmethod(lambda settings, sink: bench_edges(0, sink))
        config.data["ltc"] = dict(config.get("ltc", {}) or {}, enabled=True)

    controls = ControlsBridge()
    meters = MeterBridge(store=controls.store)
    # Meters are asked for only when macros are in use: a macro can trigger on a level.
    macros_on = bool((config.get("features", {}) or {}).get("macros", True))
    worker_args = {"meter_state": meters.state, "meter_mode": "unicast" if macros_on else "off",
                   "on_meter_feed": meters.note_feed, "value_store": controls.store}
    if args.demo:
        from dm7gui.mock import MockWorker
        worker = MockWorker(warmup=float(config.get("warmup", 4.0)), mode="ok",
                            settings=args.demo_settings, **worker_args)
    else:
        worker = SessionWorker(warmup=float(config.get("warmup", 4.0)), **worker_args)
    # The selection SuperRack follows.
    channels = ChannelsBridge(store=controls.store, meters=None)
    session = ConnectionController(config=config, worker=worker, meters=meters,
                                   controls=controls, extras=[channels])
    controls.bind(session)
    channels.bind(session)
    scenes = SceneBridge(store=controls.store)
    scenes.bind(session)

    reader = LtcReader(config.get("ltc", {}) or {})
    macros = AppMacros(store=controls.store, meters=meters.state, ltc=reader, scenes=scenes,
                       path=data / "macros.json")
    macros.bind(session)
    cues = ShowCues(reader=reader, macros=macros, scenes=scenes, config=config,
                    path=data / "cues.json")

    from dm7gui import wavesdirect
    wavesdirect.PANEL_NAME = paths.APP_NAME        # what SuperRack and the log call this end
    waves = WavesBridge(channels=channels, config=config, scenes=scenes)
    worker.deskSelect.connect(waves.onDesk)
    relay = SelKeyRelay()
    relay.key.connect(waves.onSelKey)
    controls.store.sel_key = relay.key.emit

    adapter = AdapterChoice(config)
    features = Features(config, waves, cues, macros)
    shell = App(page=args.page or "console", data_dir=str(data))
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(paths.resource("qml")))
    ctx = engine.rootContext()
    for name, obj in (("Session", session), ("Scenes", scenes), ("Waves", waves),
                      ("Cues", cues), ("Shell", shell),
                      ("Adapter", adapter), ("Macros", macros), ("Features", features)):
        ctx.setContextProperty(name, obj)
    w, _, h = str(args.size).partition("x")
    ctx.setContextProperty("initialWidth", int(w or 1440))
    ctx.setContextProperty("initialHeight", int(h or 900))
    ctx.setContextProperty("initialSection", args.section or "")

    engine.load(QUrl.fromLocalFile(str(paths.resource("qml", "Main.qml"))))
    if not engine.rootObjects():
        print("[dm7link] QML failed to load", file=sys.stderr)
        session.shutdown()
        return 1
    window = engine.rootObjects()[0]

    def shutdown() -> None:
        macros.shutdown()
        cues.shutdown()
        waves.shutdown()
        session.shutdown()

    app.aboutToQuit.connect(shutdown)
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    nudge = QTimer()
    nudge.start(200)
    nudge.timeout.connect(lambda: None)

    if args.screenshot:
        shots = [int(x) for x in str(args.shot_at).split(",") if x.strip().isdigit()] or [2500]
        for at in shots:
            def grab(ms: int = at) -> None:
                path = f"{args.screenshot}-{ms}.png"
                image = window.grabWindow()
                if not image.isNull():
                    image.save(path)
                    print(f"[dm7link] wrote {path}")
            QTimer.singleShot(at, grab)
        QTimer.singleShot(max(shots) + 600, app.quit)
    elif args.selftest:
        QTimer.singleShot(2500, app.quit)

    QTimer.singleShot(0, cues.boot)
    QTimer.singleShot(0, waves.boot)
    QTimer.singleShot(0, session.startup)
    QTimer.singleShot(0, features.boot)
    code = app.exec()
    engine.clearComponentCache()
    del engine
    shutdown()
    return code


if __name__ == "__main__":
    raise SystemExit(main())

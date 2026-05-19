#!/usr/bin/env python3
"""Tk GUI for the RISCV_RV32I_5STAGE UART bootloader workflow."""

from __future__ import annotations

from pathlib import Path
import os
import queue
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


TOOLS_DIR = Path(__file__).resolve().parents[1]
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from common.project_config import (  # noqa: E402
    DEFAULT_APP_DISPLAY,
    DEFAULT_APP_NAME,
    DEFAULT_BAUD,
    DEFAULT_PACKET,
    PROJECT_ROOT,
    output_name_for_app_display,
    packet_path_for_app_name,
)


def discover_apps() -> dict[str, Path]:
    apps: dict[str, Path] = {}
    app_root = PROJECT_ROOT / "sw" / "apps"
    for main_c in sorted(app_root.glob("*/src/main.c")):
        app_dir = main_c.parents[1]
        display_name = app_dir.name
        apps[display_name] = main_c
    return apps


def list_windows_ports() -> list[str]:
    if os.name != "nt":
        return []

    ports: set[str] = set()

    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DEVICEMAP\SERIALCOMM") as key:
            index = 0
            while True:
                try:
                    _name, value, _value_type = winreg.EnumValue(key, index)
                except OSError:
                    break
                if isinstance(value, str) and value.upper().startswith("COM"):
                    ports.add(value.upper())
                index += 1
    except OSError:
        pass

    if not ports:
        try:
            ps = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-Command",
                    "[System.IO.Ports.SerialPort]::GetPortNames()",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
        except OSError:
            ps = None
        if ps and ps.returncode == 0:
            for line in ps.stdout.splitlines():
                port = line.strip()
                if port.upper().startswith("COM"):
                    ports.add(port.upper())

    return sorted(ports, key=lambda item: int(item[3:]) if item[3:].isdigit() else item)


def list_ports() -> tuple[list[str], bool]:
    pyserial_available = True
    try:
        import serial.tools.list_ports
    except ImportError:
        pyserial_available = False
        return list_windows_ports(), pyserial_available

    ports = [port.device for port in serial.tools.list_ports.comports()]
    if not ports:
        ports = list_windows_ports()
    return ports, pyserial_available


class UartBootloaderGui(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("RISCV RV32I UART Bootloader")
        self.geometry("980x680")

        self.apps = discover_apps()
        default_app = DEFAULT_APP_DISPLAY if DEFAULT_APP_DISPLAY in self.apps else (next(iter(self.apps), ""))

        self.port_var = tk.StringVar()
        self.baud_var = tk.StringVar(value=str(DEFAULT_BAUD))
        self.app_var = tk.StringVar(value=default_app)
        self.name_var = tk.StringVar(value=output_name_for_app_display(default_app) if default_app else DEFAULT_APP_NAME)
        self.packet_var = tk.StringVar(value=str(DEFAULT_PACKET))
        self.command_var = tk.StringVar()
        self.no_ack_var = tk.BooleanVar(value=False)
        self.status_var = tk.StringVar(value="Ready")
        self.console_state_var = tk.StringVar(value="Closed")

        self.serial_obj = None
        self.serial_stop = threading.Event()
        self.serial_thread: threading.Thread | None = None
        self.log_queue: queue.Queue[str] = queue.Queue()
        self.ui_queue: queue.Queue[tuple[str, str]] = queue.Queue()

        self._build_ui()
        self.refresh_ports()
        self.after(100, self._drain_log_queue)

    def _build_ui(self) -> None:
        root = ttk.Frame(self, padding=12)
        root.pack(fill=tk.BOTH, expand=True)

        conn = ttk.LabelFrame(root, text="Connection", padding=10)
        conn.pack(fill=tk.X)

        ttk.Label(conn, text="COM").grid(row=0, column=0, sticky=tk.W)
        self.port_box = ttk.Combobox(conn, textvariable=self.port_var, width=18)
        self.port_box.grid(row=0, column=1, padx=6, sticky=tk.W)
        ttk.Button(conn, text="Refresh", command=self.refresh_ports).grid(row=0, column=2, padx=4)

        ttk.Label(conn, text="Baud").grid(row=0, column=3, padx=(20, 0), sticky=tk.W)
        ttk.Combobox(
            conn,
            textvariable=self.baud_var,
            width=12,
            values=("9600", "57600", "115200", "230400", "460800", "921600"),
        ).grid(row=0, column=4, padx=6, sticky=tk.W)

        ttk.Checkbutton(conn, text="No ACK wait", variable=self.no_ack_var).grid(row=0, column=5, padx=(20, 0))
        ttk.Button(conn, text="Open Console", command=self.open_console).grid(row=0, column=6, padx=(20, 4))
        ttk.Button(conn, text="Close", command=self.close_console).grid(row=0, column=7, padx=4)
        ttk.Label(conn, textvariable=self.console_state_var).grid(row=0, column=8, padx=(12, 0), sticky=tk.W)

        app = ttk.LabelFrame(root, text="Build and Download", padding=10)
        app.pack(fill=tk.X, pady=(10, 0))

        ttk.Label(app, text="App").grid(row=0, column=0, sticky=tk.W)
        self.app_box = ttk.Combobox(app, textvariable=self.app_var, values=list(self.apps.keys()), width=22, state="readonly")
        self.app_box.grid(row=0, column=1, padx=6, sticky=tk.W)
        self.app_box.bind("<<ComboboxSelected>>", self._on_app_selected)

        ttk.Label(app, text="Output name").grid(row=0, column=2, padx=(20, 0), sticky=tk.W)
        ttk.Entry(app, textvariable=self.name_var, width=24).grid(row=0, column=3, padx=6, sticky=tk.W)

        ttk.Button(app, text="Generate SoC", command=self.generate_soc).grid(row=0, column=4, padx=(20, 4))
        ttk.Button(app, text="Build BootRom", command=self.build_bootrom).grid(row=0, column=5, padx=4)
        ttk.Button(app, text="Build App", command=self.build_app).grid(row=0, column=6, padx=4)
        ttk.Button(app, text="Build + Download", command=self.download_app).grid(row=0, column=7, padx=4)

        packet = ttk.LabelFrame(root, text="UART DATA", padding=10)
        packet.pack(fill=tk.X, pady=(10, 0))

        ttk.Entry(packet, textvariable=self.packet_var).grid(row=0, column=0, sticky=tk.EW)
        packet.columnconfigure(0, weight=1)
        ttk.Button(packet, text="Browse", command=self.browse_packet).grid(row=0, column=1, padx=6)
        ttk.Button(packet, text="Use Built App", command=self.use_built_app_packet).grid(row=0, column=2, padx=4)
        ttk.Button(packet, text="Send UART DATA", command=self.send_packet).grid(row=0, column=3, padx=4)

        console = ttk.LabelFrame(root, text="Serial Console", padding=10)
        console.pack(fill=tk.BOTH, expand=True, pady=(10, 0))

        self.log = tk.Text(console, height=24, wrap=tk.WORD)
        self.log.pack(fill=tk.BOTH, expand=True)

        cmd_bar = ttk.Frame(console)
        cmd_bar.pack(fill=tk.X, pady=(8, 0))
        ttk.Entry(cmd_bar, textvariable=self.command_var).pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(cmd_bar, text="Send Line", command=self.send_console_line).pack(side=tk.LEFT, padx=(8, 4))
        ttk.Button(cmd_bar, text="Clear", command=self.clear_log).pack(side=tk.LEFT, padx=4)

        ttk.Label(root, textvariable=self.status_var).pack(anchor=tk.W, pady=(8, 0))

    def _on_app_selected(self, _event=None) -> None:
        app_display = self.app_var.get()
        self.name_var.set(output_name_for_app_display(app_display))
        self.use_built_app_packet()

    def append_log(self, text: str) -> None:
        self.log.insert(tk.END, text)
        self.log.see(tk.END)

    def enqueue_log(self, text: str) -> None:
        self.log_queue.put(text)

    def enqueue_status(self, text: str) -> None:
        self.ui_queue.put(("status", text))

    def enqueue_console_state(self, text: str) -> None:
        self.ui_queue.put(("console", text))

    def _drain_log_queue(self) -> None:
        try:
            while True:
                key, value = self.ui_queue.get_nowait()
                if key == "status":
                    self.status_var.set(value)
                elif key == "console":
                    self.console_state_var.set(value)
        except queue.Empty:
            pass

        try:
            while True:
                self.append_log(self.log_queue.get_nowait())
        except queue.Empty:
            pass
        self.after(100, self._drain_log_queue)

    def clear_log(self) -> None:
        self.log.delete("1.0", tk.END)

    def refresh_ports(self) -> None:
        ports, pyserial_available = list_ports()
        self.port_box["values"] = ports
        if ports and not self.port_var.get():
            self.port_var.set(ports[0])
        if ports:
            status = "Ports: " + ", ".join(ports)
            if not pyserial_available:
                status += " (pyserial missing: install with python -m pip install pyserial)"
            self.status_var.set(status)
        else:
            self.status_var.set("No COM ports found, or pyserial is missing")

    def selected_app_path(self) -> Path | None:
        app_display = self.app_var.get()
        return self.apps.get(app_display)

    def selected_baud(self) -> int | None:
        try:
            return int(self.baud_var.get(), 10)
        except ValueError:
            messagebox.showerror("Invalid baud", "Baud must be an integer.")
            return None

    def selected_port(self) -> str | None:
        port = self.port_var.get().strip()
        if not port:
            messagebox.showerror("No COM port", "Select a COM port first.")
            return None
        return port

    def run_command(self, command: list[str], title: str) -> None:
        self.close_console_for_action()

        def worker() -> None:
            self.enqueue_status(f"Running: {title}")
            self.enqueue_log("\n> " + " ".join(command) + "\n")
            proc = subprocess.Popen(
                command,
                cwd=PROJECT_ROOT,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                bufsize=1,
            )
            assert proc.stdout is not None
            for line in proc.stdout:
                self.enqueue_log(line)
            return_code = proc.wait()
            self.enqueue_status("Done" if return_code == 0 else f"Failed: {return_code}")

        threading.Thread(target=worker, daemon=True).start()

    def generate_soc(self) -> None:
        self.run_command([sys.executable, str(TOOLS_DIR / "soc" / "generate_soc_artifacts.py")], "Generate SoC")

    def build_bootrom(self) -> None:
        self.run_command([sys.executable, str(TOOLS_DIR / "firmware" / "build_bootrom.py")], "Build BootRom")

    def build_app(self) -> None:
        app_path = self.selected_app_path()
        if app_path is None:
            messagebox.showerror("No app", "No app source was found.")
            return
        name = self.name_var.get().strip() or output_name_for_app_display(self.app_var.get())
        self.run_command(
            [
                sys.executable,
                str(TOOLS_DIR / "firmware" / "build_uart_app.py"),
                "--app",
                str(app_path),
                "--name",
                name,
            ],
            "Build App",
        )

    def download_app(self) -> None:
        port = self.selected_port()
        baud = self.selected_baud()
        app_path = self.selected_app_path()
        if port is None or baud is None or app_path is None:
            return
        name = self.name_var.get().strip() or output_name_for_app_display(self.app_var.get())
        command = [
            sys.executable,
            str(TOOLS_DIR / "uart" / "download_uart_app.py"),
            port,
            "--app",
            str(app_path),
            "--name",
            name,
            "--baud",
            str(baud),
        ]
        if self.no_ack_var.get():
            command.append("--no-ack")
        self.run_command(command, "Build + Download")

    def browse_packet(self) -> None:
        path = filedialog.askopenfilename(
            initialdir=str(PROJECT_ROOT / "output" / "uart_app"),
            title="Select UART DATA",
            filetypes=(("UART DATA", "*.bin"), ("All files", "*.*")),
        )
        if path:
            self.packet_var.set(path)

    def use_built_app_packet(self) -> None:
        name = self.name_var.get().strip() or output_name_for_app_display(self.app_var.get())
        self.packet_var.set(str(packet_path_for_app_name(name)))

    def send_packet(self) -> None:
        port = self.selected_port()
        baud = self.selected_baud()
        packet = Path(self.packet_var.get().strip())
        if port is None or baud is None:
            return
        if not packet.exists():
            messagebox.showerror("Missing UART DATA", f"UART DATA file does not exist:\n{packet}")
            return
        command = [
            sys.executable,
            str(TOOLS_DIR / "uart" / "send_loader_packet.py"),
            port,
            str(packet),
            "--baud",
            str(baud),
        ]
        if self.no_ack_var.get():
            command.append("--no-ack")
        self.run_command(command, "Send UART DATA")

    def close_console_for_action(self) -> None:
        if self.serial_obj is not None:
            self.close_console()
            time.sleep(0.1)

    def open_console(self) -> None:
        if self.serial_obj is not None:
            return
        port = self.selected_port()
        baud = self.selected_baud()
        if port is None or baud is None:
            return

        try:
            import serial
        except ImportError:
            messagebox.showerror("pyserial missing", "Install pyserial: python -m pip install pyserial")
            return

        try:
            self.serial_obj = serial.Serial(port, baud, timeout=0.1)
            self.serial_stop.clear()
        except Exception as exc:
            self.serial_obj = None
            messagebox.showerror("Open failed", str(exc))
            return

        self.console_state_var.set(f"Open {port} @ {baud}")
        self.status_var.set("Serial console open")
        self.enqueue_log(f"\n[CONSOLE OPEN] {port} @ {baud}\n")
        self.serial_thread = threading.Thread(target=self._serial_reader, daemon=True)
        self.serial_thread.start()

    def close_console(self) -> None:
        self.serial_stop.set()
        serial_obj = self.serial_obj
        self.serial_obj = None
        if serial_obj is not None:
            try:
                serial_obj.close()
            except Exception:
                pass
            self.enqueue_log("\n[CONSOLE CLOSED]\n")
        self.console_state_var.set("Closed")
        self.status_var.set("Serial console closed")

    def _serial_reader(self) -> None:
        while not self.serial_stop.is_set():
            serial_obj = self.serial_obj
            if serial_obj is None:
                return
            try:
                data = serial_obj.read(256)
            except Exception as exc:
                self.enqueue_log(f"\n[CONSOLE READ ERROR] {exc}\n")
                self.serial_obj = None
                self.enqueue_console_state("Closed")
                self.enqueue_status("Serial console closed")
                return
            if data:
                try:
                    self.enqueue_log(data.decode("utf-8", errors="replace"))
                except Exception:
                    self.enqueue_log(repr(data) + "\n")

    def send_console_line(self) -> None:
        serial_obj = self.serial_obj
        if serial_obj is None:
            messagebox.showerror("Console closed", "Open the serial console first.")
            return
        text = self.command_var.get()
        if not text:
            return
        try:
            serial_obj.write((text + "\n").encode("utf-8"))
            serial_obj.flush()
        except Exception as exc:
            messagebox.showerror("Send failed", str(exc))
            return
        self.enqueue_log(f"\n> {text}\n")
        self.command_var.set("")

    def destroy(self) -> None:
        self.close_console()
        super().destroy()


if __name__ == "__main__":
    UartBootloaderGui().mainloop()

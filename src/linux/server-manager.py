#!/usr/bin/env python3
"""Server Manager - Native Linux desktop application for game server management."""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GLib', '2.0')
gi.require_version('Pango', '1.0')

from gi.repository import Gtk, Gio, GLib, Pango
from core.server_manager import ServerManager
from ui.window import MainWindow

class Application(Gtk.Application):
    def __init__(self):
        super().__init__(
            application_id='com.rasmus.server-manager',
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        self.manager = ServerManager()

    def do_activate(self):
        win = MainWindow(self.manager)
        self.add_window(win)
        win.show_all()

def main():
    app = Application()
    app.run(sys.argv)

if __name__ == '__main__':
    main()

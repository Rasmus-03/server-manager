"""Main window for the Server Manager Linux application."""

import os
import threading

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GLib', '2.0')
gi.require_version('Pango', '1.0')
from gi.repository import Gtk, GLib, Pango, Gdk

from core.server_manager import GAME_SERVER_KINDS


CSS = """
@define-color bg-color #0f172a;
@define-color sidebar-color #0b1324;
@define-color surface-color #1e293b;
@define-color text-color #e2e8f0;
@define-color muted-color #64748b;
@define-color accent-color #f59e0b;
@define-color green-color #22c55e;
@define-color red-color #ef4444;
@define-color blue-color #3b82f6;

window, .background {
    background-color: @bg-color;
    color: @text-color;
}

.sidebar {
    background-color: @sidebar-color;
    border-right: 1px solid @surface-color;
}

.sidebar-header {
    padding: 16px;
    font-size: 18px;
    font-weight: bold;
    color: @accent-color;
}

.server-list {
    background-color: @sidebar-color;
}

.server-item {
    padding: 10px 16px;
    border: none;
    background-color: transparent;
    color: @text-color;
    font-size: 13px;
    text-align: left;
}

.server-item:hover {
    background-color: @surface-color;
}

.server-item:active, .server-item:checked {
    background-color: @surface-color;
    border-left: 3px solid @accent-color;
}

.server-item-label {
    font-weight: 600;
}

.server-item-status {
    font-size: 11px;
    color: @muted-color;
}

.status-dot {
    border-radius: 50%;
    min-width: 8px;
    min-height: 8px;
}

.status-dot.online { background-color: @green-color; }
.status-dot.offline { background-color: @red-color; }

.panel {
    background-color: @sidebar-color;
    border: 1px solid @surface-color;
    border-radius: 8px;
    padding: 16px;
}

.panel-title {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: @muted-color;
    margin-bottom: 8px;
}

.stat-card {
    background-color: @sidebar-color;
    border: 1px solid @surface-color;
    border-radius: 8px;
    padding: 12px;
}

.stat-label {
    font-size: 10px;
    text-transform: uppercase;
    color: @muted-color;
}

.stat-value {
    font-size: 20px;
    font-weight: bold;
    margin-top: 4px;
}

.btn {
    padding: 8px 16px;
    border-radius: 6px;
    border: 1px solid @surface-color;
    background-color: transparent;
    color: @text-color;
    font-weight: 600;
    font-size: 13px;
}

.btn:hover { border-color: @accent-color; }
.btn-primary { background-color: @green-color; color: white; border: none; }
.btn-primary:hover { background-color: #16a34a; }
.btn-danger { background-color: @red-color; color: white; border: none; }
.btn-danger:hover { background-color: #dc2626; }
.btn-sm { padding: 4px 10px; font-size: 11px; }

.console-text {
    font-family: 'JetBrains Mono', 'Fira Code', 'Noto Mono', monospace;
    font-size: 12px;
    background-color: #020617;
    color: #a5b4fc;
    padding: 12px;
}

.entry, combobox, spinbutton {
    background-color: @bg-color;
    color: @text-color;
    border: 1px solid @surface-color;
    border-radius: 6px;
    padding: 6px 10px;
}

.entry:focus { border-color: @accent-color; }

.notebook {
    background-color: @bg-color;
}

.notebook tab {
    background-color: @sidebar-color;
    color: @muted-color;
    padding: 8px 16px;
}

.notebook tab:checked {
    background-color: @surface-color;
    color: @text-color;
}
"""


class MainWindow(Gtk.ApplicationWindow):
    def __init__(self, manager):
        super().__init__(title="Server Manager")
        self.manager = manager
        self.set_default_size(1200, 800)
        self.set_position(Gtk.WindowPosition.CENTER)

        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self._build_ui()
        self._load_servers()
        GLib.timeout_add(3000, self._poll_resources)

    def _build_ui(self):
        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        self.add(paned)

        # Sidebar
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        sidebar.get_style_context().add_class("sidebar")
        sidebar.set_size_request(240, -1)

        header = Gtk.Label(label="<b>Server Manager</b>")
        header.set_use_markup(True)
        header.get_style_context().add_class("sidebar-header")
        header.set_xalign(0.0)
        sidebar.pack_start(header, False, False, 0)

        # New server button
        add_btn = Gtk.Button(label="+ New Server")
        add_btn.get_style_context().add_class("btn")
        add_btn.connect("clicked", self._on_new_server)
        sidebar.pack_start(add_btn, False, False, 4)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        self.server_list = Gtk.ListBox()
        self.server_list.get_style_context().add_class("server-list")
        self.server_list.connect("row-activated", self._on_server_selected)
        scroll.add(self.server_list)
        sidebar.pack_start(scroll, True, True, 0)

        paned.add1(sidebar)

        # Main content
        self.notebook = Gtk.Notebook()
        self.notebook.get_style_context().add_class("notebook")
        self.notebook.set_show_tabs(False)

        self.page_dashboard = self._build_dashboard()
        self.page_console = self._build_console()
        self.page_config = self._build_config()
        self.page_backups = self._build_backups()

        self.notebook.append_page(self.page_dashboard, Gtk.Label(label="Dashboard"))
        self.notebook.append_page(self.page_console, Gtk.Label(label="Console"))
        self.notebook.append_page(self.page_config, Gtk.Label(label="Config"))
        self.notebook.append_page(self.page_backups, Gtk.Label(label="Backups"))

        paned.add2(self.notebook)
        paned.set_position(240)

    def _build_dashboard(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_start(24)
        box.set_margin_end(24)
        box.set_margin_top(24)
        box.set_margin_bottom(24)

        # Header
        self.header_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.header_name = Gtk.Label()
        self.header_name.set_use_markup(True)
        self.header_name.set_xalign(0.0)
        self.header_name.get_style_context().add_class("panel-title")

        self.header_meta = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        self.header_actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.btn_start = Gtk.Button(label="▶ Start")
        self.btn_start.get_style_context().add_class("btn")
        self.btn_start.connect("clicked", self._on_start)
        self.btn_stop = Gtk.Button(label="■ Stop")
        self.btn_stop.get_style_context().add_class("btn", "btn-danger")
        self.btn_stop.connect("clicked", self._on_stop)
        self.btn_kill = Gtk.Button(label="✕ Kill")
        self.btn_kill.get_style_context().add_class("btn")
        self.btn_kill.connect("clicked", self._on_kill)
        self.header_actions.pack_start(self.btn_start, False, False, 0)
        self.header_actions.pack_start(self.btn_stop, False, False, 0)
        self.header_actions.pack_start(self.btn_kill, False, False, 0)

        header_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        header_left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        header_left.pack_start(self.header_name, False, False, 0)
        header_left.pack_start(self.header_meta, False, False, 0)
        header_row.pack_start(header_left, True, True, 0)
        header_row.pack_end(self.header_actions, False, False, 0)
        box.pack_start(header_row, False, False, 0)

        # Tab buttons
        tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        tab_btns = [
            ("Dashboard", 0),
            ("Console", 1),
            ("Config", 2),
            ("Backups", 3),
        ]
        for label, idx in tab_btns:
            btn = Gtk.ToggleButton(label=label)
            btn.get_style_context().add_class("btn", "btn-sm")
            btn.connect("toggled", self._on_tab_switch, idx)
            if idx == 0:
                btn.set_active(True)
                self._active_tab_btn = btn
            tab_box.pack_start(btn, False, False, 0)

        self.tab_buttons = [btn for btn in tab_box.get_children()]
        box.pack_start(tab_box, False, False, 0)

        # Stats grid
        self.stats_grid = Gtk.Grid()
        self.stats_grid.set_column_spacing(12)
        self.stats_grid.set_row_spacing(12)
        self.stats_grid.set_hexpand(True)

        self.stat_labels = {}
        for i, (key, label) in enumerate([
            ("status", "Status"), ("game", "Game"), ("cpu", "CPU"),
            ("ram", "RAM"), ("port", "Port"), ("players", "Players")
        ]):
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            card.get_style_context().add_class("stat-card")
            lbl = Gtk.Label(label=label)
            lbl.get_style_context().add_class("stat-label")
            lbl.set_xalign(0.0)
            val = Gtk.Label(label="--")
            val.get_style_context().add_class("stat-value")
            val.set_xalign(0.0)
            card.pack_start(lbl, False, False, 0)
            card.pack_start(val, False, False, 0)
            self.stat_labels[key] = val
            self.stats_grid.attach(card, i % 3, i // 3, 1, 1)

        box.pack_start(self.stats_grid, False, False, 0)

        # Resource panel
        self.resource_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.resource_panel.get_style_context().add_class("panel")
        rtitle = Gtk.Label(label="<b>Resource Usage</b>")
        rtitle.set_use_markup(True)
        rtitle.set_xalign(0.0)
        self.resource_panel.pack_start(rtitle, False, False, 0)

        self.cpu_bar = Gtk.LevelBar()
        self.cpu_bar.set_max_value(100)
        self.cpu_bar.set_min_value(0)
        self.cpu_bar.set_size_request(-1, 8)
        cpu_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.cpu_label = Gtk.Label(label="CPU: 0%")
        cpu_row.pack_start(self.cpu_label, False, False, 0)
        cpu_row.pack_start(self.cpu_bar, True, True, 0)
        self.resource_panel.pack_start(cpu_row, False, False, 0)

        self.ram_bar = Gtk.LevelBar()
        self.ram_bar.set_max_value(100)
        self.ram_bar.set_min_value(0)
        self.ram_bar.set_size_request(-1, 8)
        ram_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.ram_label = Gtk.Label(label="RAM: 0 MB")
        ram_row.pack_start(self.ram_label, False, False, 0)
        ram_row.pack_start(self.ram_bar, True, True, 0)
        self.resource_panel.pack_start(ram_row, False, False, 0)

        box.pack_start(self.resource_panel, False, False, 0)

        # Connection panel
        self.conn_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.conn_panel.get_style_context().add_class("panel")
        ctitle = Gtk.Label(label="<b>Connection</b>")
        ctitle.set_use_markup(True)
        ctitle.set_xalign(0.0)
        self.conn_panel.pack_start(ctitle, False, False, 0)

        self.conn_labels = {}
        for key, label in [("address", "Address"), ("playit", "Playit"), ("local", "Local")]:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            lbl = Gtk.Label(label=f"{label}:")
            lbl.set_xalign(0.0)
            val = Gtk.Label(label="--")
            val.set_xalign(0.0)
            val.set_selectable(True)
            row.pack_start(lbl, False, False, 0)
            row.pack_start(val, False, False, 0)
            self.conn_panel.pack_start(row, False, False, 0)
            self.conn_labels[key] = val

        box.pack_start(self.conn_panel, False, False, 0)

        empty_box = Gtk.Box()
        box.pack_start(empty_box, True, True, 0)
        return box

    def _build_console(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.set_margin_start(24)
        box.set_margin_end(24)
        box.set_margin_top(24)
        box.set_margin_bottom(24)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.console_view = Gtk.TextView()
        self.console_view.get_style_context().add_class("console-text")
        self.console_view.set_editable(False)
        self.console_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.console_buffer = self.console_view.get_buffer()
        scroll.add(self.console_view)

        input_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.cmd_entry = Gtk.Entry()
        self.cmd_entry.set_hexpand(True)
        self.cmd_entry.connect("activate", self._on_send_command)
        send_btn = Gtk.Button(label="Send")
        send_btn.get_style_context().add_class("btn", "btn-primary")
        send_btn.connect("clicked", self._on_send_command)

        input_box.pack_start(self.cmd_entry, True, True, 0)
        input_box.pack_start(send_btn, False, False, 0)

        box.pack_start(scroll, True, True, 0)
        box.pack_start(input_box, False, False, 0)
        return box

    def _build_config(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_start(24)
        box.set_margin_end(24)
        box.set_margin_top(24)
        box.set_margin_bottom(24)

        self.config_grid = Gtk.Grid()
        self.config_grid.set_column_spacing(16)
        self.config_grid.set_row_spacing(12)

        self.config_widgets = {}
        fields = [
            ("name", "Server Name", Gtk.Entry),
            ("port", "Server Port", Gtk.Entry),
            ("ram_gb", "RAM (GB)", self._spin_button(1, 64, 1)),
            ("cpu_threads", "CPU Threads", self._spin_button(1, 128, 1)),
            ("max_players", "Max Players", Gtk.Entry),
            ("public_address", "Public Address", Gtk.Entry),
            ("playit_address", "Playit Address", Gtk.Entry),
            ("motd", "MOTD", Gtk.Entry),
        ]

        for i, (key, label, widget_type) in enumerate(fields):
            lbl = Gtk.Label(label=label)
            lbl.set_xalign(0.0)
            lbl.get_style_context().add_class("stat-label")
            if callable(widget_type):
                w = widget_type()
            else:
                w = widget_type()
            self.config_widgets[key] = w
            if hasattr(w, "connect") and key not in ("cpu_threads", "ram_gb"):
                if isinstance(w, Gtk.Entry):
                    w.connect("changed", self._on_config_changed, key)
            self.config_grid.attach(lbl, i % 2, (i // 2) * 2, 1, 1)
            self.config_grid.attach(w, i % 2, (i // 2) * 2 + 1, 1, 1)

        box.pack_start(self.config_grid, False, False, 0)

        # Automation panel
        auto_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        auto_panel.get_style_context().add_class("panel")
        atitle = Gtk.Label(label="<b>Automation</b>")
        atitle.set_use_markup(True)
        atitle.set_xalign(0.0)
        auto_panel.pack_start(atitle, False, False, 0)

        self.cb_autorestart = Gtk.CheckButton(label="Auto-restart on crash")
        self.cb_autorestart.connect("toggled", self._on_toggle, "auto_restart")
        auto_panel.pack_start(self.cb_autorestart, False, False, 0)

        self.cb_backup = Gtk.CheckButton(label="Auto-backup")
        self.cb_backup.connect("toggled", self._on_toggle, "backup_enabled")
        auto_panel.pack_start(self.cb_backup, False, False, 0)

        box.pack_start(auto_panel, False, False, 0)
        empty = Gtk.Box()
        box.pack_start(empty, True, True, 0)
        return box

    def _build_backups(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.set_margin_start(24)
        box.set_margin_end(24)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        lbl = Gtk.Label(label="Backup system is initialized when auto-backup is enabled in Config.")
        lbl.get_style_context().add_class("stat-label")
        box.pack_start(lbl, False, False, 0)
        return box

    def _spin_button(self, min_v, max_v, step):
        def create():
            btn = Gtk.SpinButton()
            btn.set_range(min_v, max_v)
            btn.set_increment(step)
            btn.connect("value-changed", self._on_spin_changed)
            return btn
        return create

    def _on_tab_switch(self, btn, idx):
        if btn.get_active():
            for b in self.tab_buttons:
                b.set_active(b == btn)
            self.notebook.set_current_page(idx)
            self._refresh_current_view()

    def _load_servers(self):
        self.server_list.forall(lambda w: self.server_list.remove(w))
        for s in self.manager.instances:
            row = Gtk.ListBoxRow()
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            box.set_margin_start(12)
            box.set_margin_end(12)
            box.set_margin_top(8)
            box.set_margin_bottom(8)

            dot = Gtk.Label(label="●")
            dot.set_xalign(0.5)
            if s.is_running:
                dot.get_style_context().add_class("status-dot")
                dot.override_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(0.13, 0.77, 0.37, 1))
            else:
                dot.override_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(0.94, 0.27, 0.27, 1))

            info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            name_lbl = Gtk.Label(label=s.name)
            name_lbl.get_style_context().add_class("server-item-label")
            name_lbl.set_xalign(0.0)
            status_lbl = Gtk.Label(label=f"{'Online' if s.is_running else 'Offline'} · {s.game_kind}")
            status_lbl.get_style_context().add_class("server-item-status")
            status_lbl.set_xalign(0.0)
            info_box.pack_start(name_lbl, False, False, 0)
            info_box.pack_start(status_lbl, False, False, 0)

            box.pack_start(dot, False, False, 0)
            box.pack_start(info_box, True, True, 0)
            row.add(box)

            if s.id == self.manager.selected_id:
                self.server_list.select_row(row)

            self.server_list.add(row)

        self.server_list.show_all()

    def _on_server_selected(self, listbox, row):
        idx = row.get_index()
        if idx < len(self.manager.instances):
            self.manager.selected_id = self.manager.instances[idx].id
            self._refresh_current_view()

    def _refresh_current_view(self):
        s = self.manager.selected
        if not s:
            return
        page = self.notebook.get_current_page()
        if page == 0:
            self._update_dashboard(s)
        elif page == 1:
            self._update_console(s)
        elif page == 2:
            self._update_config(s)

    def _update_dashboard(self, s):
        self.header_name.set_markup(f"<b>{s.name}</b>")
        self._update_stats(s)

        kind = GAME_SERVER_KINDS.get(s.game_kind, {})
        status_text = f"<span color=\"{'#22c55e' if s.is_running else '#ef4444'}\">{'●' if s.is_running else '○'}</span> {'Online' if s.is_running else 'Offline'}"
        meta = Gtk.Label()
        meta.set_markup(
            f"{status_text}   {kind.get('name', s.game_kind)}   Port: {s.server_port}"
        )
        meta.set_xalign(0.0)
        for child in self.header_meta.get_children():
            self.header_meta.remove(child)
        self.header_meta.pack_start(meta, False, False, 0)
        self.header_meta.show_all()

        self.btn_start.set_visible(not s.is_running)
        self.btn_stop.set_visible(s.is_running)

    def _update_stats(self, s):
        kind = GAME_SERVER_KINDS.get(s.game_kind, {})
        self.stat_labels["status"].set_markup(
            f"<span color=\"{'#22c55e' if s.is_running else '#ef4444'}\">{'Online' if s.is_running else 'Offline'}</span>"
        )
        self.stat_labels["game"].set_text(kind.get("name", s.game_kind))
        self.stat_labels["cpu"].set_text(f"{s.cpu_usage:.1f}%" if s.is_running else "0%")
        self.stat_labels["ram"].set_text(f"{s.ram_usage_mb:.0f} MB" if s.is_running else "0 MB")
        self.stat_labels["port"].set_text(s.server_port)
        self.stat_labels["players"].set_text(s.max_players)

        self.cpu_label.set_text(f"CPU: {s.cpu_usage:.1f}%")
        self.cpu_bar.set_value(min(s.cpu_usage, 100))
        self.ram_label.set_text(f"RAM: {s.ram_usage_mb:.0f} MB / {s.ram_gb} GB")
        ram_max_mb = s.ram_gb * 1024
        self.ram_bar.set_value(min(s.ram_usage_mb / ram_max_mb * 100 if ram_max_mb > 0 else 0, 100))

        self.conn_labels["address"].set_text(s.public_join_address or "Not set")
        self.conn_labels["playit"].set_text(s.playit_target_address or "Not set")
        self.conn_labels["local"].set_text(s.local_address)

    def _update_console(self, s):
        self.console_buffer.set_text(s.log_output or "Server output will appear here.")
        mark = self.console_buffer.create_mark("end", self.console_buffer.get_end_iter(), False)
        self.console_view.scroll_to_mark(mark, 0.0, True, 0.0, 0.0)

    def _update_config(self, s):
        self.config_widgets["name"].set_text(s.name)
        self.config_widgets["port"].set_text(s.port)
        self.config_widgets["ram_gb"].set_value(s.ram_gb)
        self.config_widgets["cpu_threads"].set_value(s.cpu_threads)
        self.config_widgets["max_players"].set_text(s.max_players)
        self.config_widgets["public_address"].set_text(s.public_join_address)
        self.config_widgets["playit_address"].set_text(s.playit_target_address)
        self.config_widgets["motd"].set_text(s.motd)
        self.cb_autorestart.set_active(s.auto_restart)
        self.cb_backup.set_active(s.backup_enabled)

    def _on_start(self, btn):
        s = self.manager.selected
        if s:
            threading.Thread(target=s.start, daemon=True).start()
            self._refresh_current_view()

    def _on_stop(self, btn):
        s = self.manager.selected
        if s:
            threading.Thread(target=s.stop, daemon=True).start()
            self._refresh_current_view()

    def _on_kill(self, btn):
        s = self.manager.selected
        if s:
            s.kill()
            self._refresh_current_view()

    def _on_send_command(self, widget):
        s = self.manager.selected
        cmd = self.cmd_entry.get_text().strip()
        if s and cmd:
            s.send_command(cmd)
            self.cmd_entry.set_text("")

    def _on_config_changed(self, widget, key):
        s = self.manager.selected
        if not s:
            return
        if key == "name":
            s.name = widget.get_text()
        elif key == "port":
            s.port = widget.get_text()
        elif key == "max_players":
            s.max_players = widget.get_text()
        elif key == "public_address":
            s.public_join_address = widget.get_text()
        elif key == "playit_address":
            s.playit_target_address = widget.get_text()
        elif key == "motd":
            s.motd = widget.get_text()
        self.manager.save()

    def _on_spin_changed(self, widget):
        s = self.manager.selected
        if not s:
            return
        s.ram_gb = int(self.config_widgets["ram_gb"].get_value())
        s.cpu_threads = int(self.config_widgets["cpu_threads"].get_value())
        self.manager.save()

    def _on_toggle(self, widget, key):
        s = self.manager.selected
        if not s:
            return
        value = widget.get_active()
        if key == "auto_restart":
            s.auto_restart = value
        elif key == "backup_enabled":
            s.backup_enabled = value
        self.manager.save()

    def _on_new_server(self, btn):
        dialog = NewServerDialog(self, self.manager)
        dialog.run()
        dialog.destroy()
        self._load_servers()
        self._refresh_current_view()

    def _poll_resources(self):
        s = self.manager.selected
        if s and s.is_running:
            self._update_stats(s)
        self._load_servers()
        return True


class NewServerDialog(Gtk.Dialog):
    def __init__(self, parent, manager):
        super().__init__(title="Create Server", transient_for=parent, flags=0)
        self.manager = manager
        self.set_default_size(450, -1)

        box = self.get_content_area()
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.set_margin_top(16)
        box.set_margin_bottom(16)
        box.set_spacing(12)

        fields = [
            ("name", "Server Name", Gtk.Entry()),
            ("path", "Server Path", Gtk.Entry()),
        ]
        self.entries = {}
        for key, label, widget in fields:
            lbl = Gtk.Label(label=label, xalign=0.0)
            box.pack_start(lbl, False, False, 0)
            box.pack_start(widget, False, False, 0)
            self.entries[key] = widget

        self.entries["name"].set_text(f"Server {len(manager.instances) + 1}")
        self.entries["path"].set_text(os.path.expanduser(f"~/minecraft-server-{len(manager.instances) + 1}"))

        # Game kind
        lbl = Gtk.Label(label="Game", xalign=0.0)
        box.pack_start(lbl, False, False, 0)
        self.game_combo = Gtk.ComboBoxText()
        for key, info in GAME_SERVER_KINDS.items():
            self.game_combo.append(key, info["name"])
        self.game_combo.set_active(0)
        box.pack_start(self.game_combo, False, False, 0)

        self.add_button("Cancel", Gtk.ResponseType.CANCEL)
        self.add_button("Create", Gtk.ResponseType.OK)
        self.show_all()

    def do_response(self, response):
        if response == Gtk.ResponseType.OK:
            name = self.entries["name"].get_text().strip()
            path = self.entries["path"].get_text().strip()
            game = self.game_combo.get_active_id() or "minecraft"
            if name and path:
                self.manager.add_server(name, path, game)

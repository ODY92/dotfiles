import fcntl
import json
import os
from pathlib import Path
import signal
import shutil
import socket
import subprocess
import sys
import threading
import time
from urllib.parse import quote

from search import calculate, index_files, rank
from motion import Animator

ROOT = Path(__file__).resolve().parent
RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', f'/tmp/spotlight26-{os.getuid()}'))
SOCKET = RUNTIME / 'spotlight26.sock'
PROTOCOL = b'glass-clear-v4'

def send(command):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(.6)
            client.connect(str(SOCKET))
            client.sendall(command.encode())
            return client.recv(16) == b'OK'
    except OSError:
        return False

def protocol_version():
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(.4)
            client.connect(str(SOCKET))
            client.sendall(b'--version')
            return client.recv(32)
    except OSError:
        return None

def stop_legacy():
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(.3)
            client.connect(str(RUNTIME / 'sphere-launcher.sock'))
            client.sendall(b'quit')
            client.recv(32)
    except OSError:
        pass

def configure_compositor():
    if not shutil.which('hyprctl'):
        return
    rule = 'hl.layer_rule({name="spotlight26-glass",match={namespace="spotlight26"},blur=true,ignore_alpha=0.1,no_anim=true}); if hl.plugin.hyprglass then local hg=hl.plugin.hyprglass; hg.preset("spotlight-clear",{inherits="pomme",glass_opacity=0.55,tint_color=0x00000000,blur_strength=1.0,refraction_strength=0.30,fresnel_strength=0.65,specular_strength=0.8,edge_thickness=0.045}); hg.layer("spotlight26",{preset="spotlight-clear",mask_mode="contour",mask_threshold=0.1,mask_feather=0.03}) end'
    try:
        subprocess.run(['hyprctl', 'eval', rule], check=True, timeout=2, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        print('Spotlight : rechargez Hyprland pour appliquer la règle de fondu.', file=sys.stderr)

def run():
    command = sys.argv[1] if len(sys.argv) > 1 else '--toggle'
    if command not in ('--toggle', '--show', '--hide', '--quit', '--preview'):
        print('spotlight26 [--toggle|--show|--hide|--quit|--preview]')
        return 2
    if command != '--preview':
        version = protocol_version()
        if version and version != PROTOCOL:
            send('--quit')
            for attempt in range(20):
                time.sleep(.05)
                if protocol_version() is None: break
            else:
                print('La précédente instance de Spotlight ne s’est pas encore arrêtée.', file=sys.stderr)
                return 1
        if send(command): return 0
    if command in ('--quit', '--hide'):
        return 0
    RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = (RUNTIME / 'spotlight26.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        for attempt in range(15):
            time.sleep(.1)
            if send(command):
                return 0
        print('Spotlight démarre déjà.', file=sys.stderr)
        return 1
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('Gdk', '3.0')
    gi.require_version('GtkLayerShell', '0.1')
    from gi.repository import Gtk, Gdk, Gio, GLib, GtkLayerShell, Pango
    if not Gtk.init_check()[0]:
        print('Spotlight : impossible de joindre la session graphique.', file=sys.stderr)
        return 1
    if command != '--preview':
        stop_legacy()
        configure_compositor()

    class Glyph(Gtk.DrawingArea):
        def __init__(self, kind, size=22):
            super().__init__()
            self.kind = kind
            self.set_size_request(size, size)
            self.set_halign(Gtk.Align.CENTER)
            self.set_valign(Gtk.Align.CENTER)
            self.connect('draw', self.draw_icon)

        def draw_icon(self, widget, context):
            context.scale(self.get_allocated_width() / 24, self.get_allocated_height() / 24)
            context.set_source_rgba(.81, .91, .95, .70)
            context.set_line_width(1.35)
            context.set_line_cap(1)
            context.set_line_join(1)
            def line(points):
                context.move_to(*points[0])
                for point in points[1:]: context.line_to(*point)
                context.stroke()
            if self.kind == 'search':
                context.arc(10.2, 10.2, 6.4, 0, 6.284); context.stroke(); line([(15, 15), (20.7, 20.7)])
            elif self.kind == 'apps':
                line([(8, 17), (14.5, 4.5)]); line([(10, 4.5), (18.5, 20)]); line([(4, 15), (19.8, 15)]); line([(5.4, 19.8), (6.5, 17.8)])
            elif self.kind == 'files':
                context.move_to(3.2, 8); context.line_to(3.2, 5.2); context.curve_to(3.2, 4.2, 3.7, 3.7, 4.7, 3.7); context.line_to(9, 3.7); context.line_to(11.5, 6.8); context.line_to(19.3, 6.8); context.curve_to(20.3, 6.8, 20.8, 7.3, 20.8, 8.3); context.line_to(20.8, 18.8); context.curve_to(20.8, 19.8, 20.3, 20.3, 19.3, 20.3); context.line_to(4.7, 20.3); context.curve_to(3.7, 20.3, 3.2, 19.8, 3.2, 18.8); context.close_path(); context.stroke(); line([(3.6, 9), (20.4, 9)])
            elif self.kind == 'actions':
                for offset in (0, 8):
                    context.move_to(4, 6 + offset); context.line_to(9.8, 2.1 + offset); context.curve_to(11.2, 1.1 + offset, 12.8, 1.1 + offset, 14.2, 2.1 + offset); context.line_to(20, 6 + offset); context.curve_to(21.3, 6.9 + offset, 21.3, 8.1 + offset, 20, 9 + offset); context.line_to(14.2, 12.9 + offset); context.curve_to(12.8, 13.9 + offset, 11.2, 13.9 + offset, 9.8, 12.9 + offset); context.line_to(4, 9 + offset); context.curve_to(2.7, 8.1 + offset, 2.7, 6.9 + offset, 4, 6 + offset); context.stroke()
            elif self.kind == 'more':
                context.arc(12, 12, 9, 0, 6.284); context.stroke()
                for horizontal in (8, 12, 16): context.arc(horizontal, 12, .9, 0, 6.284); context.fill()
            else:
                context.move_to(8, 3); context.line_to(14, 3); context.line_to(20, 9); context.line_to(20, 17); context.curve_to(20, 18.4, 19.4, 19, 18, 19); context.line_to(15, 19); context.stroke(); line([(14, 3), (14, 9), (20, 9)])
                context.move_to(5, 7); context.line_to(10, 7); context.line_to(16, 13); context.line_to(16, 21); context.curve_to(16, 22.4, 15.4, 23, 14, 23); context.line_to(5, 23); context.curve_to(3.6, 23, 3, 22.4, 3, 21); context.line_to(3, 9); context.curve_to(3, 7.6, 3.6, 7, 5, 7); context.stroke(); line([(10, 7), (10, 13), (16, 13)])
            return False

    class Spotlight:
        def __init__(self):
            self.mode = 'all'
            self.visible = False
            settings = Gtk.Settings.get_default()
            self.animations = bool(settings.get_property('gtk-enable-animations'))
            self.motion = Animator(GLib.get_monotonic_time, self.animations)
            self.expanded = None
            self.surface_width = 472
            self.result_signature = None
            self.monitor_height = 900
            self.monitor_width = 1440
            self.file_index = []
            self.index_started = False
            self.index_ready = False
            self.items = []
            self.clipboard_text = None
            self.clipboard_history = []
            self.applications = sorted([app for app in Gio.AppInfo.get_all() if app.should_show()], key=lambda app: app.get_display_name().casefold())
            self.window = Gtk.Window(title='Spotlight 26')
            self.window.set_name('spotlight-window')
            self.window.set_wmclass('spotlight26', 'Spotlight26')
            self.window.set_decorated(False)
            self.window.set_app_paintable(True)
            self.window.set_skip_taskbar_hint(True)
            screen = self.window.get_screen()
            visual = screen.get_rgba_visual()
            if visual: self.window.set_visual(visual)
            self.layer = GtkLayerShell.is_supported()
            if self.layer:
                GtkLayerShell.init_for_window(self.window)
                GtkLayerShell.set_namespace(self.window, 'spotlight26')
                GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
                for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
                    GtkLayerShell.set_anchor(self.window, edge, True)
                GtkLayerShell.set_exclusive_zone(self.window, -1)
            else:
                self.window.set_default_size(1000, 700)
            self.window.connect('delete-event', lambda *_: self.hide() or True)
            self.window.connect('key-press-event', self.key)
            self.backdrop = Gtk.EventBox()
            self.backdrop.set_name('backdrop')
            self.backdrop.set_visible_window(False)
            self.backdrop.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
            self.backdrop.connect('button-press-event', self.outside)
            self.window.add(self.backdrop)
            self.panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
            self.panel.set_name('spotlight-panel')
            self.panel.set_halign(Gtk.Align.CENTER)
            self.panel.set_valign(Gtk.Align.START)
            self.panel.set_margin_top(160)
            self.backdrop.add(self.panel)
            bar = Gtk.Box(spacing=12)
            bar.set_name('spotlight-bar')
            self.panel.pack_start(bar, False, False, 0)
            self.surface = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            self.surface.set_name('surface')
            self.surface.set_valign(Gtk.Align.START)
            self.surface.set_size_request(472, -1)
            bar.pack_start(self.surface, False, False, 0)
            pill = Gtk.Box(spacing=2)
            pill.set_name('search-pill')
            self.surface.pack_start(pill, False, False, 0)
            self.search_icon = Glyph('search', 22)
            pill.pack_start(self.search_icon, False, False, 0)
            self.entry = Gtk.Entry()
            self.entry.set_name('query')
            self.entry.set_width_chars(20)
            self.entry.set_placeholder_text('Rechercher')
            self.entry.connect('changed', lambda *_: self.refresh())
            self.entry.connect('activate', lambda *_: self.activate_selected())
            pill.pack_start(self.entry, True, True, 0)
            self.more = Gtk.Button()
            self.more.set_name('more')
            self.more.set_tooltip_text('Catégories de recherche')
            self.more.get_accessible().set_name('Catégories de recherche')
            self.more.add(Glyph('more', 25))
            self.more.connect('clicked', self.open_menu)
            self.more.set_no_show_all(True)
            pill.pack_start(self.more, False, False, 0)
            self.buttons = {}
            self.category_revealers = {}
            for kind, title in [('apps', 'Applications'), ('files', 'Fichiers'), ('actions', 'Actions'), ('clipboard', 'Presse-papiers')]:
                button = Gtk.Button()
                button.set_valign(Gtk.Align.START)
                button.set_no_show_all(True)
                button.get_style_context().add_class('category')
                button.set_tooltip_text(title)
                button.get_accessible().set_name(title)
                button.add(Glyph(kind, 24))
                button.connect('clicked', lambda _button, category=kind: self.set_mode(category))
                self.buttons[kind] = button
                revealer = Gtk.Revealer()
                revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_LEFT)
                revealer.set_transition_duration(210 if self.animations else 0)
                revealer.add(button)
                self.category_revealers[kind] = revealer
                bar.pack_start(revealer, False, False, 0)
            self.results = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            self.results.set_name('results')
            self.section = Gtk.Label(label='Suggestions', xalign=0)
            self.section.set_name('section')
            self.results.pack_start(self.section, False, False, 0)
            self.list = Gtk.ListBox()
            self.list.set_selection_mode(Gtk.SelectionMode.SINGLE)
            self.list.connect('row-activated', lambda _list, row: self.activate(row.get_index()))
            self.other_list = Gtk.ListBox()
            self.other_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
            self.other_list.connect('row-activated', lambda _list, row: self.activate(row.get_index()))
            self.result_stack = Gtk.Stack()
            self.result_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
            self.result_stack.set_transition_duration(150 if self.animations else 0)
            self.result_stack.set_interpolate_size(True)
            self.result_stack.add_named(self.list, 'first')
            self.result_stack.add_named(self.other_list, 'second')
            scroller = Gtk.ScrolledWindow()
            scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroller.set_propagate_natural_height(True)
            scroller.set_max_content_height(470)
            scroller.add(self.result_stack)
            self.results.pack_start(scroller, True, True, 0)
            self.result_revealer = Gtk.Revealer()
            self.result_revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
            self.result_revealer.set_transition_duration(250 if self.animations else 0)
            self.result_revealer.add(self.results)
            self.surface.pack_start(self.result_revealer, False, False, 0)
            provider = Gtk.CssProvider()
            provider.load_from_path(str(ROOT / 'style.css'))
            Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        def outside(self, widget, event):
            target = Gtk.get_event_widget(event)
            while target:
                if target == self.panel:
                    return False
                target = target.get_parent()
            self.hide()
            return False

        def show(self):
            self.motion.cancel_all()
            self.expanded = None
            self.mode = 'all'
            self.clipboard_text = None
            self.clipboard_history = []
            self.entry.set_text('')
            display = Gdk.Display.get_default()
            pointer = display.get_default_seat().get_pointer()
            if pointer:
                _, horizontal, vertical = pointer.get_position()
                monitor = display.get_monitor_at_point(horizontal, vertical)
            else:
                monitor = display.get_monitor(0)
            if monitor:
                self.monitor_height = monitor.get_geometry().height
                self.monitor_width = monitor.get_geometry().width
                if self.layer: GtkLayerShell.set_monitor(self.window, monitor)
            self.visible = True
            if not self.window.get_visible(): self.panel.set_opacity(0)
            self.window.show_all()
            self.refresh()
            if self.layer: GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.EXCLUSIVE)
            else: self.window.present()
            self.entry.grab_focus()
            self.fade_to(1)
            if not self.expanded:
                for index, button in enumerate(self.buttons.values()):
                    button.set_opacity(0)
                    self.motion.animate(f'category-{index}', button, 0, 1, 220, button.set_opacity, delay=24 * index)

        def hide(self):
            self.motion.cancel_all()
            self.visible = False
            self.clipboard_text = None
            self.clipboard_history = []
            if self.layer: GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)
            self.fade_to(0)
            return False

        def fade_to(self, target):
            initial = self.panel.get_opacity()
            def finished():
                if not target and not self.visible: self.window.hide()
            self.motion.animate('visibility', self.panel, initial, target, 250 if target else 150, self.panel.set_opacity, finished, closing=not target)

        def resize_surface(self, target):
            def resize(value):
                self.surface_width = value
                self.surface.set_size_request(round(value), -1)
            self.motion.animate('surface-width', self.surface, self.surface_width, target, 270, resize)

        def open_menu(self, button):
            menu = Gtk.Menu()
            for mode, title in [('all', 'Recherche'), ('apps', 'Applications'), ('files', 'Fichiers'), ('actions', 'Actions'), ('clipboard', 'Presse-papiers')]:
                item = Gtk.MenuItem(label=title)
                item.connect('activate', lambda _item, category=mode: self.set_mode(category))
                menu.append(item)
            menu.show_all()
            menu.popup_at_widget(button, Gdk.Gravity.SOUTH_EAST, Gdk.Gravity.NORTH_EAST, None)

        def toggle(self):
            if self.visible: self.hide()
            else: self.show()
            return False

        def set_mode(self, mode):
            self.mode = mode
            if mode == 'clipboard':
                Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).request_text(self.receive_clipboard, None)
                if shutil.which('cliphist') and shutil.which('wl-copy'):
                    def history():
                        try:
                            result = subprocess.run(['cliphist', 'list'], capture_output=True, timeout=2, check=True)
                            entries = result.stdout[:1000000].decode(errors='replace').splitlines()[:100]
                            GLib.idle_add(self.receive_history, entries)
                        except (OSError, subprocess.SubprocessError):
                            pass
                    threading.Thread(target=history, daemon=True).start()
            if mode == 'files': self.start_index()
            self.refresh()
            self.entry.grab_focus()

        def start_index(self):
            if self.index_started: return
            self.index_started = True
            def index():
                found = index_files()
                GLib.idle_add(self.receive_index, found)
            threading.Thread(target=index, daemon=True).start()

        def receive_index(self, files):
            self.file_index = files
            self.index_ready = True
            if self.visible and self.mode in ('files', 'all'): self.refresh()
            return False

        def receive_clipboard(self, clipboard, text, _data):
            if self.visible and self.mode == 'clipboard':
                self.clipboard_text = (text or '')[:10000]
                self.refresh()

        def receive_history(self, entries):
            if self.visible and self.mode == 'clipboard':
                self.clipboard_history = entries
                self.refresh()
            return False

        def candidates(self, query):
            output = []
            if self.mode in ('all', 'apps'):
                for app in self.applications:
                    title, detail = app.get_display_name(), app.get_description() or 'Application'
                    score = rank(query, title, detail)
                    if score:
                        output.append((score, {'title': title, 'detail': detail, 'kind': 'app', 'app': app, 'icon': app.get_icon()}))
            if self.mode == 'files' or (self.mode == 'all' and query):
                for item in self.file_index:
                    score = rank(query, item['title'], item['detail'])
                    if score: output.append((score, dict(item, kind='file')))
            if self.mode in ('all', 'actions'):
                actions = [('Ouvrir le dossier personnel', 'Fichiers', ['gio', 'open', str(Path.home())]), ('Ouvrir un terminal', 'Terminal', ['xdg-terminal-exec']), ('Paramètres du système', 'Réglages', ['systemsettings']), ('Moniteur système', 'Mémoire et processus', ['plasma-systemmonitor'])]
                for title, detail, argv in actions:
                    if shutil.which(argv[0]):
                        score = rank(query, title, detail)
                        if score: output.append((score, {'title': title, 'detail': detail, 'kind': 'action', 'argv': argv}))
                result = calculate(query)
                if result is not None:
                    output.append((120, {'title': f'= {result}', 'detail': 'Entrée pour copier le résultat', 'kind': 'copy', 'text': result}))
            if self.mode == 'clipboard' and self.clipboard_text:
                text = self.clipboard_text
                if rank(query, text): output.append((100, {'title': text.replace('\n', ' ')[:90], 'detail': 'Texte actuellement copié · Entrée pour le recopier', 'kind': 'copy', 'text': text}))
            if self.mode == 'clipboard':
                for order, record in enumerate(self.clipboard_history):
                    title = record.partition('\t')[2] or record
                    if rank(query, title):
                        output.append((90 - order / 100, {'title': title[:90], 'detail': 'Historique système · Entrée pour recopier', 'kind': 'history', 'record': record}))
            output.sort(key=lambda pair: (-pair[0], pair[1]['title'].casefold()))
            items = [item for score, item in output[:7]]
            if query and self.mode in ('all', 'apps', 'actions'):
                items.append({'title': f'Rechercher « {query[:60]} » sur le Web', 'detail': 'DuckDuckGo · Entrée pour ouvrir le navigateur', 'kind': 'web', 'query': query})
            return items

        def refresh(self):
            query = self.entry.get_text().strip()[:300]
            expanded = bool(query) or self.mode != 'all'
            layout_changed = self.expanded != expanded
            surface_style = self.surface.get_style_context()
            if expanded: surface_style.add_class('expanded')
            else: surface_style.remove_class('expanded')
            width = min(800 if expanded else 472, self.monitor_width - (70 if expanded else 300))
            if layout_changed:
                self.resize_surface(max(280, width))
                self.expanded = expanded
            self.panel.set_margin_top(max(50, int(self.monitor_height * .18)))
            self.entry.set_placeholder_text({'all': 'Rechercher', 'apps': 'Applications', 'files': 'Fichiers', 'actions': 'Actions', 'clipboard': 'Presse-papiers'}[self.mode])
            self.search_icon.kind = 'search' if self.mode == 'all' else self.mode
            self.search_icon.set_size_request(32 if expanded else 22, 32 if expanded else 22)
            self.search_icon.queue_draw()
            self.more.set_visible(expanded)
            self.more.get_child().show()
            for mode, button in self.buttons.items():
                context = button.get_style_context()
                if mode == self.mode: context.add_class('active')
                else: context.remove_class('active')
                button.show()
                button.get_child().show()
                self.category_revealers[mode].set_reveal_child(not expanded)
            if self.mode == 'all' and len(query) >= 2: self.start_index()
            if not query and self.mode == 'all':
                self.items = []
                self.result_signature = None
                self.result_revealer.set_reveal_child(False)
                return
            items = self.candidates(query)
            signature = tuple((item['kind'], item['title'], item['detail'], item.get('path'), item.get('query'), item.get('record'), item.get('text')) for item in items)
            self.section.set_visible(self.mode in ('actions', 'all'))
            self.section.set_text('Suggestions' if self.mode == 'actions' else 'Meilleurs résultats')
            if signature == self.result_signature:
                self.result_revealer.set_reveal_child(True)
                return
            previous_row = self.list.get_selected_row()
            previous_index = previous_row.get_index() if previous_row else 0
            selected = self.result_signature[previous_index][:2] if self.result_signature and previous_index < len(self.result_signature) else None
            self.result_signature = signature
            self.items = items
            self.list, self.other_list = self.other_list, self.list
            self.other_list.set_sensitive(False)
            self.list.set_sensitive(True)
            for index in range(8): self.motion.cancel(f'row-{index}')
            for child in self.list.get_children(): self.list.remove(child)
            for index, item in enumerate(self.items):
                row = Gtk.ListBoxRow()
                box = Gtk.Box(spacing=18)
                if item.get('icon'):
                    icon = Gtk.Image.new_from_gicon(item['icon'], Gtk.IconSize.DIALOG)
                elif item['kind'] in ('copy', 'history'):
                    icon = Glyph('clipboard', 36)
                else:
                    names = {'file': 'text-x-generic', 'web': 'web-browser', 'copy': 'edit-copy', 'history': 'edit-copy', 'action': 'system-run'}
                    icon = Gtk.Image.new_from_icon_name(names.get(item['kind'], 'application-x-executable'), Gtk.IconSize.DIALOG)
                if isinstance(icon, Gtk.Image): icon.set_pixel_size(36)
                box.pack_start(icon, False, False, 0)
                labels = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
                for key, style in [('title', 'result-title'), ('detail', 'result-detail')]:
                    label = Gtk.Label(label=item[key], xalign=0)
                    label.set_ellipsize(Pango.EllipsizeMode.END)
                    label.set_max_width_chars(38)
                    label.get_style_context().add_class(style)
                    labels.pack_start(label, False, False, 0)
                box.pack_start(labels, True, True, 0)
                affordance = Gtk.Label(label='↵')
                affordance.get_style_context().add_class('row-affordance')
                if item['kind'] in ('copy', 'history'):
                    copy_icon = Glyph('clipboard', 23)
                    copy_icon.set_tooltip_text('Entrée pour copier')
                    box.pack_start(copy_icon, False, False, 8)
                else:
                    box.pack_start(affordance, False, False, 0)
                row.add(box)
                self.list.add(row)
                if layout_changed:
                    row.set_opacity(0)
                    self.motion.animate(f'row-{index}', row, 0, 1, 190, row.set_opacity, delay=min(index * 18, 90))
            if not self.items:
                message = 'Aucun résultat'
                if self.mode == 'files' and not self.index_ready: message = 'Indexation des noms de fichiers…'
                if self.mode == 'clipboard': message = 'Aucun texte dans le presse-papiers'
                empty = Gtk.Label(label=message)
                empty.set_name('empty')
                self.list.add(empty)
            self.results.show()
            for child in self.results.get_children(): child.show_all()
            self.result_stack.set_visible_child(self.list)
            self.result_revealer.set_reveal_child(True)
            self.section.set_visible(self.mode in ('actions', 'all'))
            self.section.set_text('Suggestions' if self.mode == 'actions' else 'Meilleurs résultats')
            selected_index = next((index for index, item in enumerate(signature) if item[:2] == selected), 0)
            first = self.list.get_row_at_index(selected_index)
            if first: self.list.select_row(first)

        def activate_selected(self):
            row = self.list.get_selected_row()
            if row: self.activate(row.get_index())

        def activate(self, index):
            if not 0 <= index < len(self.items): return
            item = self.items[index]
            try:
                if item['kind'] == 'app': item['app'].launch([], None)
                elif item['kind'] == 'file': Gio.AppInfo.launch_default_for_uri(Path(item['path']).as_uri(), None)
                elif item['kind'] == 'web': Gio.AppInfo.launch_default_for_uri('https://duckduckgo.com/?q=' + quote(item['query']), None)
                elif item['kind'] == 'action': subprocess.Popen(item['argv'], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                elif item['kind'] == 'copy': Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).set_text(item['text'], -1)
                elif item['kind'] == 'history':
                    decoded = subprocess.run(['cliphist', 'decode'], input=item['record'].encode(), capture_output=True, timeout=2, check=True)
                    subprocess.run(['wl-copy'], input=decoded.stdout, timeout=2, check=True)
                self.hide()
            except (GLib.Error, OSError, subprocess.SubprocessError):
                self.entry.set_placeholder_text('Ouverture impossible · réessayez')

        def key(self, widget, event):
            if event.keyval == Gdk.KEY_Escape:
                self.hide(); return True
            if event.state & Gdk.ModifierType.CONTROL_MASK and event.keyval in (Gdk.KEY_1, Gdk.KEY_2, Gdk.KEY_3, Gdk.KEY_4):
                self.set_mode(['apps', 'files', 'actions', 'clipboard'][event.keyval - Gdk.KEY_1]); return True
            if event.keyval in (Gdk.KEY_Up, Gdk.KEY_Down):
                rows = self.list.get_children()
                if self.items:
                    current = self.list.get_selected_row()
                    index = current.get_index() if current else -1
                    index = (index + (1 if event.keyval == Gdk.KEY_Down else -1)) % len(self.items)
                    self.list.select_row(rows[index])
                return True
            return False

    app = Spotlight()
    if command == '--preview':
        app.show()
        def capture():
            allocation = app.panel.get_allocation()
            position = app.panel.translate_coordinates(app.window, 0, 0)
            image = Gdk.pixbuf_get_from_window(app.window.get_window(), position[0] - 12, position[1] - 12, allocation.width + 24, allocation.height + 24)
            image.savev(str(ROOT / 'preview.png'), 'png', [], [])
            Gtk.main_quit()
            return False
        GLib.timeout_add(500, capture)
        Gtk.main()
        return 0
    SOCKET.unlink(missing_ok=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(SOCKET))
    os.chmod(SOCKET, 0o600)
    server.listen(4)
    def listener():
        while True:
            try:
                connection, _ = server.accept()
                with connection:
                    connection.settimeout(1)
                    message = connection.recv(64).decode(errors='replace')
                    if message == '--version':
                        connection.sendall(PROTOCOL)
                        continue
                    callback = {'--toggle': app.toggle, '--show': app.show, '--hide': app.hide, '--quit': Gtk.main_quit}.get(message)
                    if callback: GLib.idle_add(callback)
                    connection.sendall(b'OK')
            except OSError:
                return
    threading.Thread(target=listener, daemon=True).start()
    def stop(*_args):
        Gtk.main_quit()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    app.show()
    try:
        Gtk.main()
    finally:
        server.close()
        SOCKET.unlink(missing_ok=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(run())

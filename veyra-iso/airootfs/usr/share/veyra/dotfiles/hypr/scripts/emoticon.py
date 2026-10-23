#!/usr/bin/env python3

import tkinter as tk
import subprocess


class KaomojiPicker:
    def __init__(self, root):
        self.root = root
        self.root.title("Kaomoji Picker")

        # Colors
        self.bg_color = "#1e1e1e"
        self.btn_bg = "#2a2a2a"
        self.btn_hover = "#444444"
        self.text_color = "#ffffff"
        self.accent_color = "#aaaaaa"

        # Initialize scroll_frame as None to prevent premature updates
        self.scroll_frame = None

        self.faces_dict = {
            "Curious / Confused": [
                "•︡ᯅ•︠",
                "(•ᯅ•)",
                "( •_•)?",
                "(•˕ •;)",
                "(•_•)?",
                "(•︵•)",
                "(•_•;)",
                "(•?•)",
            ],
            "Happy / Soft": [
                "(•‿•)",
                "(•ᴗ•)",
                "(˶•‿•˶)",
                "(•ω•)",
                "(•‿•✿)",
                "(•▽•)",
                "(•‿‿•)",
                "(•ᴗ•)❤",
            ],
            "Surprised / Shocked": [
                "(•o•)",
                "(•O•)",
                "(°ロ°) !",
                "(⊙_⊙)",
                "(•◇•)",
                "(•0•)",
                "(•O•;)",
            ],
            "Cute / Shy": [
                "(•́ᴗ•̀)",
                "(•ᴗ•❀)",
                "(˶•ω•˶)",
                "(•///•)",
                "(•́⍜•̀)",
                "(•́ω•̀)",
                "(•́‿•̀)",
            ],
            "Silly / Playful": [
                "(•ڡ•)",
                "(•̀ᴗ•́)و",
                "(•ω•)ノ",
                "(•◡•) /",
                "(•̀o•́)ง",
                "(•~•)",
                "(•̀▽•́)",
            ],
            "Mild Angy": ["(•̀_•́)", "(•ˋ_ˊ•)", "(•̀︿•́)", "(•̀⤙•́)", "(•̀へ•́)", "(•̀⌓•́)"],
            "Grumpy": ["(•᷄‎ࡇ•᷅)", "(•-•)", "(•̀︹•́)", "(•¬•)", "(•̀~•́)", "(•̀_•)"],
            "Very Angy 😠": ["(•̀益•́)", "(•̀皿•́)", "(╬•̀ᗜ•́)", "(•̀o•́)ง", "(•̀Д•́)", "(•̀ロ•́)"],
            "Tiny Angy": ["•̀︿•́", "(•̀ᴖ•́)", "(•̀﹏•́)", "(•̀ω•́)"],
        }

        self.setup_window()
        self.build_ui()
        self.populate_grid()

    def setup_window(self):
        self.root.overrideredirect(True)
        self.root.attributes("-alpha", 0.95)
        self.root.attributes("-topmost", True)
        self.root.configure(
            bg=self.bg_color, highlightbackground="#333333", highlightthickness=1
        )

        # Center Window
        w, h = 440, 550
        x = (self.root.winfo_screenwidth() // 2) - (w // 2)
        y = (self.root.winfo_screenheight() // 2) - (h // 2)
        self.root.geometry(f"{w}x{h}+{x}+{y}")

        # Bindings
        self.root.bind("<Escape>", lambda e: self.root.destroy())

    def build_ui(self):
        # --- Custom Title Bar ---
        self.title_bar = tk.Frame(self.root, bg="#111111", relief="flat", bd=0)
        self.title_bar.pack(fill="x", side="top")

        # Drag mechanics
        self.title_bar.bind("<Button-1>", self.start_move)
        self.title_bar.bind("<B1-Motion>", self.do_move)

        title_label = tk.Label(
            self.title_bar,
            text="Kaomoji Picker",
            bg="#111111",
            fg=self.accent_color,
            font=("Segoe UI", 9, "bold"),
        )
        title_label.pack(side="left", padx=10, pady=5)
        title_label.bind("<Button-1>", self.start_move)
        title_label.bind("<B1-Motion>", self.do_move)

        close_btn = tk.Button(
            self.title_bar,
            text="✕",
            bg="#111111",
            fg=self.accent_color,
            font=("Segoe UI", 10),
            bd=0,
            relief="flat",
            activebackground="#e81123",
            activeforeground="white",
            cursor="hand2",
            command=self.root.destroy,
        )
        close_btn.pack(side="right", padx=5)
        close_btn.bind(
            "<Enter>", lambda e: close_btn.configure(bg="#e81123", fg="white")
        )
        close_btn.bind(
            "<Leave>", lambda e: close_btn.configure(bg="#111111", fg=self.accent_color)
        )

        # --- Search Bar ---
        search_frame = tk.Frame(self.root, bg=self.bg_color)
        search_frame.pack(fill="x", padx=15, pady=(10, 5))

        self.search_var = tk.StringVar()
        self.search_var.trace_add(
            "write", lambda *args: self.populate_grid(self.search_var.get())
        )

        search_entry = tk.Entry(
            search_frame,
            textvariable=self.search_var,
            bg=self.btn_bg,
            fg=self.text_color,
            insertbackground=self.text_color,
            font=("Segoe UI", 10),
            relief="flat",
        )
        search_entry.pack(fill="x", ipady=4)

        # Search placeholder logic
        search_entry.bind(
            "<FocusIn>",
            lambda e: (
                search_entry.delete(0, "end")
                if search_entry.get() == " Search..."
                else None
            ),
        )
        search_entry.bind(
            "<FocusOut>",
            lambda e: (
                search_entry.insert(0, " Search...") if not search_entry.get() else None
            ),
        )

        # --- Scrollable Area ---
        container = tk.Frame(self.root, bg=self.bg_color)
        container.pack(fill="both", expand=True, padx=(10, 0), pady=(0, 10))

        self.canvas = tk.Canvas(container, bg=self.bg_color, highlightthickness=0)
        scrollbar = tk.Scrollbar(
            container, orient="vertical", command=self.canvas.yview
        )

        self.scroll_frame = tk.Frame(self.canvas, bg=self.bg_color)
        self.scroll_frame.bind(
            "<Configure>",
            lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")),
        )

        self.canvas.create_window((0, 0), window=self.scroll_frame, anchor="nw")
        self.canvas.configure(yscrollcommand=scrollbar.set)

        self.canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        # Mousewheel binding - specifically handling Linux (Button-4/Button-5)
        self.root.bind("<Button-4>", self.on_mousewheel)
        self.root.bind("<Button-5>", self.on_mousewheel)

        # Insert placeholder LAST, after scroll_frame is built
        search_entry.insert(0, " Search...")

    def populate_grid(self, search_query=""):
        # Safeguard: Don't try to populate if the frame isn't built yet
        if not self.scroll_frame:
            return

        # Clear existing buttons/labels
        for widget in self.scroll_frame.winfo_children():
            widget.destroy()

        search_query = search_query.lower().strip()
        if search_query == "search...":
            search_query = ""

        row = 0
        for category, faces in self.faces_dict.items():
            cat_matches = search_query in category.lower()

            # Filter faces based on search
            if not cat_matches and search_query:
                filtered_faces = [f for f in faces if search_query in f]
            else:
                filtered_faces = faces

            if not filtered_faces:
                continue

            # Category Header
            lbl = tk.Label(
                self.scroll_frame,
                text=category,
                bg=self.bg_color,
                fg=self.accent_color,
                font=("Segoe UI", 10, "bold"),
                anchor="w",
            )
            lbl.grid(row=row, column=0, columnspan=5, sticky="w", pady=(10, 4), padx=5)
            row += 1

            # Kaomoji Buttons
            col = 0
            for face in filtered_faces:
                btn = tk.Button(
                    self.scroll_frame,
                    text=face,
                    font=("Segoe UI Emoji", 10),
                    bg=self.btn_bg,
                    fg=self.text_color,
                    activebackground=self.btn_hover,
                    activeforeground=self.text_color,
                    relief="flat",
                    cursor="hand2",
                    padx=6,
                    pady=4,
                    command=lambda f=face: self.copy_and_close(f),
                )
                btn.grid(row=row, column=col, padx=4, pady=4, sticky="nsew")

                # Dynamic hover
                btn.bind("<Enter>", lambda e, b=btn: b.configure(bg=self.btn_hover))
                btn.bind("<Leave>", lambda e, b=btn: b.configure(bg=self.btn_bg))

                col += 1
                if col >= 5:
                    col = 0
                    row += 1
            if col != 0:
                row += 1

    # --- Window Drag Logic ---
    def start_move(self, event):
        self.x = event.x
        self.y = event.y

    def do_move(self, event):
        deltax = event.x - self.x
        deltay = event.y - self.y
        x = self.root.winfo_x() + deltax
        y = self.root.winfo_y() + deltay
        self.root.geometry(f"+{x}+{y}")

    # --- Utility Logic ---
    def on_mousewheel(self, event):
        # Linux uses Button-4 (up) and Button-5 (down) for scrolling
        if event.num == 4:
            self.canvas.yview_scroll(-1, "units")
        elif event.num == 5:
            self.canvas.yview_scroll(1, "units")

    def copy_and_close(self, face):
        try:
            # Native Wayland clipboard (Hyprland)
            subprocess.run(["wl-copy"], input=face.encode("utf-8"), check=True)
        except FileNotFoundError:
            try:
                # Fallback to X11 clipboard
                subprocess.run(
                    ["xclip", "-selection", "clipboard"],
                    input=face.encode("utf-8"),
                    check=True,
                )
            except FileNotFoundError:
                # Fallback to Tkinter's built-in clipboard
                self.root.clipboard_clear()
                self.root.clipboard_append(face)
                self.root.update()

        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = KaomojiPicker(root)
    root.mainloop()

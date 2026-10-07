pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property list<string> wallpapers: []
  property string currentWallpaper: ""
  property string backend: "awww"

  // Scan wallpaper directories
  Process {
    id: scanner
    command: ["sh", "-c",
      "find ~/Pictures/Wallpapers -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort -u | head -200"
    ]
    running: false
    stdout: SplitParser {
      onRead: data => {
        const path = data.trim();
        if (path !== "") {
          root.wallpapers = [...root.wallpapers, path];
        }
      }
    }
  }

  // Load saved wallpaper path
  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.conf"
    onTextChanged: {
      const saved = configFile.text().trim();
      if (saved !== "") root.currentWallpaper = saved;
    }
  }

  Component.onCompleted: {
    scanner.running = true;
  }

  function rescan() {
    wallpapers = [];
    scanner.running = true;
  }

  function setWallpaper(path) {
    currentWallpaper = path;

    setProcess.command = ["awww", "img", path,
      "--transition-type", "grow", "--transition-pos", "center",
      "--transition-duration", "1"];
    setProcess.running = true;

    // Save to config
    saveProcess.command = ["sh", "-c", 'printf "%s" "$1" > "$HOME/.config/quickshell/wallpaper.conf"', "sh", path];
    saveProcess.running = true;
  }

  function setThemeByWallpaper(wallpaperPath) {
    genThemeProcess.command = ["sh", Quickshell.env("HOME") + "/.config/quickshell/theme-switcher/wallpaper-theme/set.sh" , wallpaperPath ];
    // genThemeProcess.command = ["hyprctl", "notify", "6", "3000", "0", wallpaperPath];

    genThemeProcess.running = true;
  }

  Process {
    id: setProcess
    command: []
    running: false
  }

  Process {
    id: saveProcess
    command: []
    running: false
  }

  Process {
    id: genThemeProcess
    command: []
    running: false
  }
}

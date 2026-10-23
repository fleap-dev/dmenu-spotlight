# dmenu-spotlight

A [dmenu](https://tools.suckless.org/dmenu/) for macOS that looks like Spotlight.

dmenu-spotlight reads lines from stdin, shows them in a Spotlight-style window, and prints the line you pick to stdout. It uses dmenu's command-line interface, so scripts written for dmenu only need the command name changed. If you symlink it as `dmenu`, they need no change at all.

```bash
printf "%s\n" "Option 1" "Option 2" "Option 3" | dmenu-spotlight
```

## Why

On Linux, dmenu, rofi, and wofi already do this job well. On macOS the closest option is [dmenu-mac](https://github.com/oNaiPs/dmenu-mac), and it has problems:

- Its window does not stay above other windows.
- Switching Spaces while it is open makes the window glitch.
- It doesn't look or behave like a Mac app.

dmenu-spotlight is a small AppKit program written to fix these. [Window behavior](#window-behavior) lists what it does differently.

## Install

You need macOS 13 or later and a Swift 6 toolchain. Xcode includes one. Without Xcode, run `xcode-select --install` to get the Command Line Tools.

```bash
swift build -c release
cp .build/release/dmenu-spotlight ~/.local/bin/
```

Any directory on your `PATH` works. The build produces a single binary with no app bundle and no third-party dependencies.

To make existing dmenu scripts use it, add a symlink:

```bash
ln -s ~/.local/bin/dmenu-spotlight ~/.local/bin/dmenu
```

## Usage

```
dmenu-spotlight [-i] [-l lines] [-p prompt] [-v]
```

dmenu-spotlight reads every line of stdin before it opens the window, so the command feeding it has to finish first. When you pick an item, it prints that item and a newline to stdout and exits with status 0. When you cancel, it prints nothing and exits with status 1. Scripts can chain on the exit status:

```bash
branch=$(git branch --format='%(refname:short)' | dmenu-spotlight -p "Switch branch") \
  && git switch "$branch"
```

### Options

| Option | Effect |
| --- | --- |
| `-p prompt` | Placeholder text in the empty search field. Defaults to "Search". |
| `-i` | Match case-insensitively. |
| `-l lines` | Show at most this many rows before the list scrolls. Defaults to 8. |
| `-v` | Print the version and exit. |

dmenu draws items on a single horizontal line unless you pass `-l`. dmenu-spotlight always draws a vertical list, like Spotlight, so `-l` only sets the height.

dmenu's appearance and placement flags, `-b`, `-f`, `-m`, `-w`, `-fn`, `-nb`, `-nf`, `-sb` and `-sf`, are accepted and ignored. The window always follows the system appearance. Accepting the flags keeps existing scripts from failing on an unknown option.

### Matching

Typing filters the list. An item stays only if every space-separated word you typed appears somewhere in it. Exact matches come first, then items that start with your first word, then everything else. Within each group, items keep their input order. This is the same matching dmenu uses.

### Keys

| Key | Action |
| --- | --- |
| Type | Filter the list |
| `↑` `↓` or `Ctrl-P` `Ctrl-N` | Move the selection |
| `Return` | Print the selected item. If nothing matches, print what you typed. |
| `Shift-Return` | Print what you typed and ignore the selection |
| `Tab` | Copy the selected item into the search field |
| `Esc` | Cancel |

Clicking an item picks it. Clicking outside the window cancels, as it does in Spotlight.

Since `Return` prints your text when nothing matches, dmenu-spotlight also works as a plain text prompt:

```bash
name=$(dmenu-spotlight -p "File name" < /dev/null)
```

## Window behavior

- The window opens centered in the upper third of the screen that has the mouse pointer, where Spotlight opens.
- It stays above all other windows, full-screen apps included.
- It stays visible and keeps keyboard focus when you switch Spaces.
- It shows no Dock icon and leaves the menu bar alone. The app you were using stays active, and focus goes back to it when the window closes.
- The background is Liquid Glass on macOS 26 and later and the system blur material on older versions. It follows light and dark mode, the selected row uses your accent color, and all text uses the system font.

## Non-goals

dmenu-spotlight is a menu, not a launcher. It doesn't index files or apps, has no plugins, and has no config file. For app launching, pipe the list of apps into it:

```bash
app=$(ls /Applications | sed -n 's/\.app$//p' | dmenu-spotlight -i -p "Open") \
  && open -a "$app"
```

## Hotkeys

dmenu-spotlight doesn't need a terminal, so a hotkey daemon such as [skhd](https://github.com/koekeishiya/skhd) can launch it directly. This line in `~/.skhdrc` opens the app picker above with Option-D:

```
alt - d : app=$(ls /Applications | sed -n 's/\.app$//p' | dmenu-spotlight -i -p Open) && open -a "$app"
```

Hotkey daemons often run with a short `PATH`. If yours can't find `dmenu-spotlight`, use its full path.

## Development

```bash
swift build
printf "%s\n" one two three | .build/debug/dmenu-spotlight
```

The code lives in `Sources/dmenu-spotlight`:

- `main.swift` reads stdin, prints the pick, and sets the exit status.
- `Options.swift` parses the command-line flags.
- `Match.swift` filters and orders items the way dmenu does.
- `Menu.swift` is the window and its key handling.

The tests cover option parsing and matching. With Xcode installed, run `swift test`. With only the Command Line Tools, SwiftPM can't find the Testing framework, so pass its location:

```bash
D=/Library/Developer/CommandLineTools/Library/Developer
swift test -Xswiftc -F$D/Frameworks -Xlinker -rpath -Xlinker $D/Frameworks -Xlinker -rpath -Xlinker $D/usr/lib
```

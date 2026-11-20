<p align="center"><img src="docs/images/evabar-icon.png" width="96" alt="EvaBar icon"></p>
<h1 align="center">EvaBar</h1>
<p align="center">A floating, keyboard-first calculator for the macOS menu bar.</p>
<p align="center"><strong>macOS 13+ · Apple Silicon</strong></p>
<p align="center"><a href="https://github.com/MichaelChene/EvaBar/releases">Releases</a> · <a href="#quick-start">Quick start</a> · <a href="#build">Build</a></p>

![EvaBar showing a live calculation in its floating bar](docs/images/evabar-bar.png)

## Quick start

1. Get `EvaBar.app` from [Releases](https://github.com/MichaelChene/EvaBar/releases) and move it to Applications.
2. Click the menu bar icon or press <kbd>Control</kbd>–<kbd>Shift</kbd>–<kbd>Space</kbd>.
3. Type an expression and press <kbd>Return</kbd> to copy the result.

Click outside the bar to dismiss it, or use the lock button to keep it on screen. The **f** button opens the function reference. Open **… → Preferences** to set a global shortcut, launch at login, change the menu bar icon, or choose a language and number format.

## Expressions

| Type | Result |
| --- | --- |
| `sqrt(144) + 3` | `15` |
| `avg(12,18,24)` | `18` |
| `sin(pi / 2)` | `1` |
| `4 % 3` | `1` |

Use a period for decimals and commas between function arguments. Trigonometric functions use radians. Preferences control the precision and separators of displayed and copied results.

EvaBar follows the system language by default and supports English, 简体中文, 繁體中文, 日本語, 한국어, Deutsch, Français, Español, Português (Brasil), and Italiano.

## Build

With Xcode 27 and Swift 6, open [EvaBar.xcodeproj](EvaBar.xcodeproj), choose the **EvaBar** scheme, and run it on **My Mac**. From the project root, you can also run:

```sh
xcodebuild -project EvaBar.xcodeproj -scheme EvaBar \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath Build/DerivedData CONFIGURATION_BUILD_DIR="$PWD/Build" build
open Build/EvaBar.app
swift test
```

## License

[MIT](LICENSE)

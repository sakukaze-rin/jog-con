# Jog-con

A native macOS utility for controlling the Adobe Premiere Pro timeline with a Nintendo Joy-Con.

> The current implementation has only been tested with **Joy-Con (L)**. Joy-Con (R), a paired left/right Joy-Con set, Pro Controller, and other compatible controllers are not currently supported or verified.

Jog-con combines SwiftUI, Apple's GameController framework, CoreMIDI virtual ports, Mackie Control relative Jog messages, and keyboard shortcuts for Premiere Pro timeline control.

## Features

- Hybrid joystick gesture recognition: a short push steps one frame, while a longer push starts continuous Jog without a manual mode switch.
- Configurable deadzone, step threshold, hold threshold, hold delay, response curve, maximum MIDI rate, inversion, and axis selection.
- Optional audio shuttle mode using Premiere's J/K/L keyboard transport controls. Long holds start at normal speed and send additional same-direction commands at a configurable interval, up to four software levels.
- MIDI Jog mode for continuous timeline movement through a virtual Mackie Control-style MIDI port.
- Automatic stop when the stick returns to center, Premiere loses focus, output is disabled, the controller disconnects, or the app exits.
- Custom Joy-Con button mappings for Premiere shortcuts, modifier combinations, panel focus shortcuts, frame stepping, markers, editing commands, and MCU transport actions.
- Learning mode for physical buttons and joystick press input when exposed by macOS.

## Important limitations

- Audio shuttle uses Premiere's keyboard shortcuts and requires Accessibility permission for Jog-con. It assumes Premiere's default J/K/L assignments unless you record custom shortcuts.
- MIDI Jog moves the timeline but may not produce audio during scrubbing. This depends on Premiere's control-surface behavior.
- The displayed playback level is the number of transport commands sent by Jog-con. Premiere determines the actual playback multiplier.
- The current controller discovery logic intentionally selects Joy-Con (L)-style names. Joy-Con (R) may expose different button names, axis aliases, and stick-button support, so it requires separate adaptation and testing.

## Setup

1. Pair a Joy-Con (L) with macOS over Bluetooth.
2. Build and launch the app:

   ```sh
   sh scripts/build-app.sh
   open build/Jog-con.app
   ```

3. Grant Jog-con permission under **System Settings → Privacy & Security → Accessibility** if you want audio shuttle or keyboard mappings.
4. In Premiere Pro, open **Preferences → Control Surface**, add **Mackie Control**, and select:
   - Input: `Jog-con Input`
   - Output: `Jog-con Output`
5. Select the detected joystick axis, center the stick, enable output, and test a short push before using continuous Jog.

## Button mappings

Click **Add Mapping**, choose a detected input or use **Learn**, then select an action. Learning disables output temporarily; re-enable output after learning.

Custom shortcuts can record Command, Shift, Option, Control, ordinary keys, and arrow keys. Presets use Adobe's default Premiere shortcuts and do not call a private Premiere API. Existing custom Premiere shortcuts should be recorded manually.

MCU Play, Stop, Rewind, and Fast Forward send MIDI control-surface messages and require the virtual ports to be connected in Premiere. The host response should be verified with the target Premiere version.

## Compatibility

### Tested

- macOS 13 or later
- Nintendo Joy-Con (L) over Bluetooth
- Adobe Premiere Pro with a Mackie Control surface configured

### Not tested or supported yet

- Nintendo Joy-Con (R)
- Paired left/right Joy-Con combinations
- Nintendo Switch Pro Controller
- Other gamepads or third-party controller drivers

macOS may recognize these devices through GameController, but that alone does not mean Jog-con will discover and map them correctly.

## Privacy

Jog-con has no network requests, telemetry, analytics SDK, account system, or upload service. It reads local GameController input, posts keyboard events to the foreground Premiere Pro process, and creates local virtual MIDI endpoints. Settings and button mappings are stored in macOS application preferences and are not uploaded.

The repository does not contain developer usernames, absolute local paths, personal files, access tokens, or signing certificates. Build output, SwiftPM caches, `.DS_Store` files, and local Xcode state are ignored by Git.

## Development

Requirements:

- macOS 13 or later
- Swift 5.9 or later
- Xcode with the macOS SDK

Run tests with:

```sh
swift test
```

Build the app bundle with:

```sh
sh scripts/build-app.sh
```

Protocol behavior and Premiere compatibility are documented separately in [`docs/TESTING.md`](docs/TESTING.md). Features that have not been verified with Premiere are marked as such.

## License

MIT. See [`LICENSE`](LICENSE).

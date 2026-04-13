# Phase 5 Manual Verification

## Scope

This checklist covers the runtime scenarios that cannot be validated reliably from SwiftPM tests alone:

- Resident-process memory behavior
- Overlay idle cost on CPU/GPU
- Signal handling and display restoration
- Dirty-shutdown recovery after `SIGKILL`
- Multi-monitor transitions

## Memory Management Review

Code inspection result:

- `OverlayWindowController.observeAppState()` uses `[weak self]` in its Combine `.sink`, so the subscription does not retain the controller.
- `AnyCancellable` values are stored in `cancellables`, which are owned by `OverlayWindowController` and released with it.
- `SignalTerminationHandler` uses `[weak self]` inside `DispatchSourceSignal` handlers, avoiding a self-retain cycle.
- `overlayWindowController` is intentionally retained for the app lifetime by `AppDelegate`; the overlay window is permanent infrastructure, not a transient window.
- `presetEditorWindowController` is also intentionally retained and reused. Closing the editor hides the window with `orderOut(_:)` instead of destroying it.
- No retain cycle was found by inspection in the current codebase.

Recommended manual check:

1. Launch the app from Xcode.
2. Open and close the preset editor 20-30 times.
3. Toggle bypass on and off repeatedly.
4. Watch Xcode Memory Graph for unexpected growth or cycles involving:
   - `OverlayWindowController`
   - `PresetEditorWindowController`
   - `NSHostingController`
   - `SignalTerminationHandler`

## Overlay Performance

Current implementation notes:

- The overlay is a fullscreen transparent `NSWindow` with two `CALayer` instances.
- Idle cost should be close to compositor-only work because there is no animation loop and no timer driving updates.
- Display transfer updates are not time-throttled, but redundant hardware writes are skipped when the computed transfer table has not changed. This avoids reapplying `CGSetDisplayTransferByTable` for overlay-only edits and repeated identical signal parameters.

Recommended Instruments passes:

1. Time Profiler
   - Idle with effect enabled for 60 seconds.
   - Drag brightness/gamma sliders for 10-15 seconds.
   - Drag overlay-only controls for 10-15 seconds.
   - Check that `CGSetDisplayTransferByTable` does not dominate samples while only overlay controls move.
2. Core Animation
   - Verify the overlay window does not trigger continuous redraws while idle.
   - Compare compositor activity with bypass on vs off.
3. Allocations
   - Leave the app running for 10-15 minutes.
   - Open/close the editor several times.
   - Confirm no monotonic growth in controller/window/layer allocations.
4. Activity Monitor
   - With effect enabled and no slider movement, confirm CPU remains near idle and energy impact stays low.

## Display Restoration

### Normal Termination

1. Launch the app.
2. Enable the effect with a non-neutral preset or live parameters that modify hardware gamma.
3. Quit with `Cmd+Q`.
4. Confirm the display returns to its baseline colors immediately.
5. In Console.app, filter by subsystem `com.diegofernandezmunoz.LumaVeil` and confirm lifecycle/display logs are present.

### SIGTERM

1. Launch the app and enable the effect.
2. Find the process ID:
   ```bash
   pgrep -x LumaVeil
   ```
3. Send:
   ```bash
   kill -TERM <pid>
   ```
4. Confirm the display is restored before exit.
5. Confirm the signal handling log appears in Console.app.

### SIGINT

1. Launch the app and enable the effect.
2. Send:
   ```bash
   kill -INT <pid>
   ```
3. Confirm the display is restored before exit.

### SIGKILL / Dirty Shutdown Recovery

`SIGKILL` cannot be intercepted. Recovery depends on `UserDefaults` key `lumaveil.effectActive` being set while a custom transfer table is active.

1. Launch the app and enable the effect.
2. Send:
   ```bash
   kill -9 <pid>
   ```
3. The display may remain altered after the forced kill. This is expected.
4. Relaunch the app.
5. Confirm the display is restored automatically during startup.
6. In Console.app, confirm the dirty-shutdown recovery log appears.

## Persistence Resilience

### Corrupted `presets.json`

1. Quit the app.
2. Edit `~/Library/Application Support/LumaVeil/presets.json` and replace its contents with invalid JSON.
3. Relaunch the app.
4. Expected result:
   - The app does not crash.
   - Factory presets are reseeded.
   - A persistence error is logged.

### Deleted Application Support Directory While Running

1. Launch the app.
2. Delete:
   ```bash
   rm -rf ~/Library/Application\\ Support/LumaVeil
   ```
3. Modify and save a preset.
4. Expected result:
   - The directory is recreated automatically on the next preset write.
   - `presets.json` is recreated.
   - The app does not crash.

## Multi-Monitor Checklist

Run the following with the effect active and again with bypass enabled:

1. Connect an external monitor.
   - Confirm the active display state remains coherent.
   - Confirm colors are restored/reapplied without leaving the old display altered.
2. Disconnect the external monitor.
   - Confirm the previous main display is restored correctly.
3. Change the resolution of the main display.
   - Confirm the overlay still covers the full screen and the hardware table remains correct.
4. Change the primary display in System Settings.
   - Confirm baseline capture moves to the new main display and the previous main display is restored.
5. Enter clamshell mode with an external monitor attached.
   - Confirm no stale transfer table remains on the internal display when it disappears.
6. Wake from sleep with the effect active.
   - Confirm overlay and transfer table remain synchronized.

## Expected Logging Filters

In Console.app, use subsystem:

- `com.diegofernandezmunoz.LumaVeil`

Useful categories:

- `lifecycle`
- `display`
- `overlay`
- `persistence`

# voxui

An immediate-mode graphical user interface library for Dart, inspired by Dear ImGui.

`voxui` is pure Dart with zero external dependencies, producing a platform-agnostic draw list of geometric and text primitives that can be rendered to any backend (WebGL, Canvas2D, software rasterizer, or game engine).

## Features

- **Immediate Mode**: Build interfaces procedurally frame-by-frame with zero state synchronization boilerplate.
- **Pure Dart & Host Decoupled**: Runs seamlessly on the Dart VM, native CLI tools, and the web.
- **DrawList Output**: Emits textured quads, rectangles, circles, lines, clipping masks, and text.
- **Built-in Widgets**:
  - `beginWindow` / `endWindow` with draggable title bars and collapsing support
  - `button`, `checkbox`, `sliderDouble`, `sliderInt`
  - `progressBar`, `collapsingHeader`, `separator`, `spacing`, `sameLine`
  - `text`, `labelValue`
- **Fully Customizable Styling**: Complete control over colors, rounding, padding, and layout metrics via `VoxStyle`.

## Usage

```dart
import 'package:voxui/voxui.dart';

void renderUi(VoxInput input) {
  voxui.beginFrame(input);

  if (voxui.beginWindow('Game Diagnostics', x: 20, y: 20, width: 260, height: 200)) {
    voxui.text('FPS: 60');
    voxui.separator();

    if (voxui.button('Pause Simulation')) {
      // Handle button click
    }

    voxui.sliderDouble('Speed', 1.0, min: 0.1, max: 3.0);
    voxui.endWindow();
  }

  final drawList = voxui.endFrame();
  // Pass drawList.commands to your renderer!
}
```

## License

MIT

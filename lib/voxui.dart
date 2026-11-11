/// Immediate-mode graphical user interface library for Dart, inspired by Dear ImGui.
///
/// Pure Dart, zero external dependencies, platform-agnostic draw-list output.
library voxui;

import 'dart:math' as math;

/// 32-bit RGBA color container.
final class VoxColor {
  final int r;
  final int g;
  final int b;
  final int a;

  const VoxColor(this.r, this.g, this.b, [this.a = 255]);

  const VoxColor.rgba(this.r, this.g, this.b, this.a);

  factory VoxColor.fromHex(int hex) {
    if (hex <= 0xFFFFFF) {
      final r = (hex >> 16) & 0xFF;
      final g = (hex >> 8) & 0xFF;
      final b = hex & 0xFF;
      return VoxColor(r, g, b, 255);
    }
    final r = (hex >> 24) & 0xFF;
    final g = (hex >> 16) & 0xFF;
    final b = (hex >> 8) & 0xFF;
    final a = hex & 0xFF;
    return VoxColor(r, g, b, a);
  }

  static const transparent = VoxColor(0, 0, 0, 0);
  static const black = VoxColor(0, 0, 0, 255);
  static const white = VoxColor(255, 255, 255, 255);
  static const red = VoxColor(230, 60, 60, 255);
  static const green = VoxColor(60, 200, 80, 255);
  static const blue = VoxColor(60, 140, 240, 255);
  static const yellow = VoxColor(240, 200, 60, 255);
  static const cyan = VoxColor(60, 220, 240, 255);
  static const darkGray = VoxColor(35, 38, 44, 255);
  static const gray = VoxColor(80, 85, 95, 255);
  static const lightGray = VoxColor(180, 185, 195, 255);

  int toRgbaInt() => (r << 24) | (g << 16) | (b << 8) | a;

  VoxColor withAlpha(int newA) => VoxColor(r, g, b, newA.clamp(0, 255));

  @override
  String toString() => 'VoxColor(r: $r, g: $g, b: $b, a: $a)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoxColor &&
          runtimeType == other.runtimeType &&
          r == other.r &&
          g == other.g &&
          b == other.b &&
          a == other.a;

  @override
  int get hashCode => Object.hash(r, g, b, a);
}

/// 2D bounding box rectangle.
final class VoxRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const VoxRect(this.x, this.y, this.width, this.height);

  double get right => x + width;
  double get bottom => y + height;

  bool contains(double px, double py) =>
      px >= x && px <= right && py >= y && py <= bottom;

  bool intersects(VoxRect other) =>
      x < other.right &&
      right > other.x &&
      y < other.bottom &&
      bottom > other.y;

  VoxRect intersect(VoxRect other) {
    final nx = math.max(x, other.x);
    final ny = math.max(y, other.y);
    final nw = math.max(0.0, math.min(right, other.right) - nx);
    final nh = math.max(0.0, math.min(bottom, other.bottom) - ny);
    return VoxRect(nx, ny, nw, nh);
  }

  @override
  String toString() => 'VoxRect($x, $y, $width, $height)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoxRect &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// Input snapshot for the current frame.
class VoxInput {
  double mouseX;
  double mouseY;
  double mouseDeltaX;
  double mouseDeltaY;
  bool isMouseDown;
  bool wasMouseClicked;
  bool wasMouseReleased;
  double scrollDeltaY;
  String textInput;
  final Set<String> keysDown;
  final Set<String> keysPressed;

  VoxInput({
    this.mouseX = 0.0,
    this.mouseY = 0.0,
    this.mouseDeltaX = 0.0,
    this.mouseDeltaY = 0.0,
    this.isMouseDown = false,
    this.wasMouseClicked = false,
    this.wasMouseReleased = false,
    this.scrollDeltaY = 0.0,
    this.textInput = '',
    Set<String>? keysDown,
    Set<String>? keysPressed,
  })  : keysDown = keysDown ?? <String>{},
        keysPressed = keysPressed ?? <String>{};
}

/// Types of drawing commands emitted into a [DrawList].
enum DrawCmdType {
  rectFilled,
  rectOutline,
  text,
  line,
  circleFilled,
  pushClip,
  popClip,
}

/// A single rendered draw command in immediate mode.
final class DrawCmd {
  final DrawCmdType type;
  final VoxRect rect;
  final VoxColor color;
  final String? text;
  final double textSize;
  final double thickness;
  final double cornerRadius;
  final double x2;
  final double y2;
  final VoxRect? clipRect;

  const DrawCmd({
    required this.type,
    this.rect = const VoxRect(0, 0, 0, 0),
    this.color = VoxColor.white,
    this.text,
    this.textSize = 13.0,
    this.thickness = 1.0,
    this.cornerRadius = 0.0,
    this.x2 = 0.0,
    this.y2 = 0.0,
    this.clipRect,
  });
}

/// Recorded queue of drawing operations produced by the immediate mode pass.
final class DrawList {
  final List<DrawCmd> commands = [];
  final List<VoxRect> _clipStack = [];

  VoxRect? get currentClip => _clipStack.isEmpty ? null : _clipStack.last;

  void pushClip(VoxRect rect) {
    final effective = _clipStack.isEmpty ? rect : _clipStack.last.intersect(rect);
    _clipStack.add(effective);
    commands.add(DrawCmd(
      type: DrawCmdType.pushClip,
      rect: effective,
      clipRect: effective,
    ));
  }

  void popClip() {
    if (_clipStack.isNotEmpty) {
      _clipStack.removeLast();
      commands.add(DrawCmd(
        type: DrawCmdType.popClip,
        clipRect: currentClip,
      ));
    }
  }

  void addRectFilled(
    double x,
    double y,
    double w,
    double h,
    VoxColor color, {
    double cornerRadius = 0.0,
  }) {
    commands.add(DrawCmd(
      type: DrawCmdType.rectFilled,
      rect: VoxRect(x, y, w, h),
      color: color,
      cornerRadius: cornerRadius,
      clipRect: currentClip,
    ));
  }

  void addRectOutline(
    double x,
    double y,
    double w,
    double h,
    VoxColor color, {
    double thickness = 1.0,
    double cornerRadius = 0.0,
  }) {
    commands.add(DrawCmd(
      type: DrawCmdType.rectOutline,
      rect: VoxRect(x, y, w, h),
      color: color,
      thickness: thickness,
      cornerRadius: cornerRadius,
      clipRect: currentClip,
    ));
  }

  void addText(
    String text,
    double x,
    double y, {
    VoxColor color = VoxColor.white,
    double size = 13.0,
  }) {
    commands.add(DrawCmd(
      type: DrawCmdType.text,
      rect: VoxRect(x, y, 0, 0),
      color: color,
      text: text,
      textSize: size,
      clipRect: currentClip,
    ));
  }

  void addLine(
    double x1,
    double y1,
    double x2,
    double y2,
    VoxColor color, {
    double thickness = 1.0,
  }) {
    commands.add(DrawCmd(
      type: DrawCmdType.line,
      rect: VoxRect(x1, y1, 0, 0),
      x2: x2,
      y2: y2,
      color: color,
      thickness: thickness,
      clipRect: currentClip,
    ));
  }

  void addCircleFilled(
    double cx,
    double cy,
    double radius,
    VoxColor color,
  ) {
    commands.add(DrawCmd(
      type: DrawCmdType.circleFilled,
      rect: VoxRect(cx - radius, cy - radius, radius * 2, radius * 2),
      color: color,
      clipRect: currentClip,
    ));
  }

  void clear() {
    commands.clear();
    _clipStack.clear();
  }
}

/// Visual styling rules for immediate mode widgets.
final class VoxStyle {
  VoxColor windowBg = const VoxColor(24, 26, 32, 240);
  VoxColor windowBorder = const VoxColor(50, 55, 68, 255);
  VoxColor titleBarBg = const VoxColor(34, 38, 48, 255);
  VoxColor titleBarActive = const VoxColor(45, 52, 68, 255);
  VoxColor titleBarText = const VoxColor(230, 235, 245, 255);

  VoxColor text = const VoxColor(220, 225, 235, 255);
  VoxColor textDisabled = const VoxColor(120, 125, 140, 255);

  VoxColor buttonBg = const VoxColor(46, 52, 66, 255);
  VoxColor buttonHover = const VoxColor(65, 75, 96, 255);
  VoxColor buttonActive = const VoxColor(35, 95, 185, 255);

  VoxColor sliderBg = const VoxColor(32, 36, 46, 255);
  VoxColor sliderGrab = const VoxColor(70, 140, 240, 255);
  VoxColor sliderGrabActive = const VoxColor(100, 170, 255, 255);

  VoxColor checkMark = const VoxColor(70, 140, 240, 255);
  VoxColor separator = const VoxColor(45, 50, 62, 255);
  VoxColor headerBg = const VoxColor(38, 44, 56, 255);

  VoxColor tabBg = const VoxColor(32, 36, 46, 255);
  VoxColor tabActive = const VoxColor(35, 95, 185, 255);
  VoxColor tabHover = const VoxColor(50, 58, 74, 255);

  VoxColor inputTextBg = const VoxColor(20, 22, 28, 255);
  VoxColor inputTextBorder = const VoxColor(60, 66, 82, 255);
  VoxColor inputTextActive = const VoxColor(70, 140, 240, 255);

  VoxColor plotBg = const VoxColor(20, 22, 28, 255);
  VoxColor plotLine = const VoxColor(240, 200, 60, 255);

  VoxColor popupBg = const VoxColor(28, 30, 38, 250);
  VoxColor popupBorder = const VoxColor(65, 72, 90, 255);

  VoxColor tooltipBg = const VoxColor(18, 20, 24, 240);
  VoxColor tooltipBorder = const VoxColor(70, 78, 96, 255);

  double windowRounding = 6.0;
  double frameRounding = 4.0;
  double windowPadding = 10.0;
  double itemSpacingX = 8.0;
  double itemSpacingY = 6.0;
  double titleBarHeight = 26.0;
  double fontSize = 13.0;
}

/// Internal tracked state for an immediate-mode window.
final class _WindowState {
  final String title;
  double x;
  double y;
  double width;
  double height;
  bool isCollapsed = false;
  bool isDragging = false;
  double dragOffsetX = 0.0;
  double dragOffsetY = 0.0;

  _WindowState({
    required this.title,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Context managing immediate-mode layout, user input, and draw list generation.
final class VoxUiContext {
  final VoxStyle style = VoxStyle();
  final DrawList drawList = DrawList();

  VoxInput input = VoxInput();
  int _activeId = 0;
  int _hoveredId = 0;

  int get activeId => _activeId;
  int get hoveredId => _hoveredId;

  final Map<int, _WindowState> _windows = {};
  final Map<int, bool> _collapsingStates = {};
  final Map<int, String> _tabBarActiveTabs = {};
  final Map<int, bool> _comboStates = {};
  final Set<int> _openPopups = {};
  final List<int> _idStack = [];

  _WindowState? _currentWindow;
  double _cursorX = 0.0;
  double _cursorY = 0.0;
  double _lineMaxY = 0.0;
  double _indent = 0.0;
  bool _sameLineRequested = false;
  double _sameLineSpacing = 0.0;

  bool _lastItemHovered = false;
  int _focusedInputId = 0;
  int _currentTabBarId = 0;

  int _columnsCount = 1;
  int _currentColumn = 0;
  double _columnWidth = 0.0;
  double _columnStartX = 0.0;
  int _frameIndex = 0;

  bool isItemHovered() => _lastItemHovered;

  /// Starts a new immediate mode UI frame.
  void beginFrame(VoxInput frameInput) {
    input = frameInput;
    drawList.clear();
    _hoveredId = 0;
    _lastItemHovered = false;
    _frameIndex++;
  }

  /// Ends the UI frame and finalizes the draw list.
  DrawList endFrame() {
    if (_currentWindow != null) {
      endWindow();
    }
    if (input.wasMouseReleased) {
      _activeId = 0;
    }
    return drawList;
  }

  /// Computes a stable 32-bit hash for a widget label given current ID stack.
  int _getId(String label) {
    var h = 0x811c9dc5;
    for (final parent in _idStack) {
      h ^= (parent & 0xFF);
      h = (h * 0x01000193) & 0x7FFFFFFF;
    }
    final codeUnits = label.codeUnits;
    for (var i = 0; i < codeUnits.length; i++) {
      h ^= codeUnits[i];
      h = (h * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }

  void pushId(int id) => _idStack.add(id);
  void popId() {
    if (_idStack.isNotEmpty) _idStack.removeLast();
  }

  /// Begins an immediate-mode window. Returns `true` if content should be rendered
  /// (i.e. window is not collapsed).
  bool beginWindow(
    String title, {
    double x = 40.0,
    double y = 40.0,
    double width = 300.0,
    double height = 200.0,
    bool autoSize = false,
  }) {
    final id = _getId(title);
    final win = _windows.putIfAbsent(
      id,
      () => _WindowState(
        title: title,
        x: x,
        y: y,
        width: width,
        height: height,
      ),
    );
    _currentWindow = win;

    // Handle title bar dragging
    final titleBarRect = VoxRect(win.x, win.y, win.width, style.titleBarHeight);
    final isHoveringTitle = titleBarRect.contains(input.mouseX, input.mouseY);

    if (isHoveringTitle && input.wasMouseClicked) {
      _activeId = id;
      win.isDragging = true;
      win.dragOffsetX = input.mouseX - win.x;
      win.dragOffsetY = input.mouseY - win.y;
    }

    if (win.isDragging) {
      if (input.isMouseDown) {
        win.x = input.mouseX - win.dragOffsetX;
        win.y = input.mouseY - win.dragOffsetY;
      } else {
        win.isDragging = false;
        if (_activeId == id) _activeId = 0;
      }
    }

    // Render Window Background
    final currentH = win.isCollapsed ? style.titleBarHeight : win.height;
    drawList.addRectFilled(
      win.x,
      win.y,
      win.width,
      currentH,
      style.windowBg,
      cornerRadius: style.windowRounding,
    );

    // Title Bar
    final titleBgColor = win.isDragging ? style.titleBarActive : style.titleBarBg;
    drawList.addRectFilled(
      win.x,
      win.y,
      win.width,
      style.titleBarHeight,
      titleBgColor,
      cornerRadius: style.windowRounding,
    );

    // Collapse button indicator
    final collapseIcon = win.isCollapsed ? '>' : 'v';
    drawList.addText(
      collapseIcon,
      win.x + 8.0,
      win.y + 6.0,
      color: style.titleBarText,
      size: style.fontSize,
    );

    // Title text
    drawList.addText(
      win.title,
      win.x + 24.0,
      win.y + 6.0,
      color: style.titleBarText,
      size: style.fontSize,
    );

    // Window border
    drawList.addRectOutline(
      win.x,
      win.y,
      win.width,
      currentH,
      style.windowBorder,
      cornerRadius: style.windowRounding,
    );

    if (win.isCollapsed) return false;

    // Setup content cursor & clip area
    _cursorX = win.x + style.windowPadding;
    _cursorY = win.y + style.titleBarHeight + style.windowPadding;
    _lineMaxY = _cursorY;
    _sameLineRequested = false;

    final contentRect = VoxRect(
      win.x + 2.0,
      win.y + style.titleBarHeight,
      win.width - 4.0,
      win.height - style.titleBarHeight - 2.0,
    );
    drawList.pushClip(contentRect);

    return true;
  }

  /// Ends the current window scope.
  void endWindow() {
    final win = _currentWindow;
    if (win == null) return;
    if (!win.isCollapsed) {
      drawList.popClip();
      // Auto-fit height if content exceeded initial size
      final contentBottom = _lineMaxY + style.windowPadding;
      if (contentBottom - win.y > win.height) {
        win.height = contentBottom - win.y;
      }
    }
    _currentWindow = null;
  }

  void _advanceLayout(double w, double h) {
    if (_sameLineRequested) {
      _cursorX += w + _sameLineSpacing;
      _lineMaxY = math.max(_lineMaxY, _cursorY + h);
      _sameLineRequested = false;
    } else {
      if (_columnsCount > 1) {
        _cursorX = _columnStartX + (_currentColumn * _columnWidth) + style.windowPadding + _indent;
      } else {
        _cursorX = (_currentWindow?.x ?? 0.0) + style.windowPadding + _indent;
      }
      _cursorY = _lineMaxY + style.itemSpacingY;
      _lineMaxY = _cursorY + h;
    }
  }

  /// Indents subsequent content to the right by [amount] pixels.
  void indent([double amount = 16.0]) {
    _indent += amount;
    _cursorX += amount;
  }

  /// Unindents subsequent content to the left by [amount] pixels.
  void unindent([double amount = 16.0]) {
    _indent = math.max(0.0, _indent - amount);
    _cursorX = math.max((_currentWindow?.x ?? 0.0) + style.windowPadding, _cursorX - amount);
  }

  /// Divides the window into [count] parallel layout columns.
  void columns(int count, {bool border = true}) {
    _columnsCount = math.max(1, count);
    _currentColumn = 0;
    final win = _currentWindow;
    final totalW = win != null ? (win.width - style.windowPadding * 2) : 300.0;
    _columnWidth = totalW / _columnsCount;
    _columnStartX = (_currentWindow?.x ?? 0.0);
    _cursorX = _columnStartX + style.windowPadding + _indent;
  }

  /// Advances cursor to the next layout column.
  void nextColumn() {
    if (_columnsCount <= 1) return;
    _currentColumn++;
    if (_currentColumn >= _columnsCount) {
      _currentColumn = 0;
      _cursorY = _lineMaxY + style.itemSpacingY;
    } else {
      _cursorY = (_currentWindow?.y ?? 0.0) + style.titleBarHeight + style.windowPadding;
    }
    _cursorX = _columnStartX + (_currentColumn * _columnWidth) + style.windowPadding + _indent;
  }

  /// Positions the next widget horizontally alongside the previous one.
  void sameLine({double spacing = 8.0}) {
    _sameLineRequested = true;
    _sameLineSpacing = spacing;
  }

  /// Adds a vertical spacing of [amount] pixels.
  void spacing([double amount = 8.0]) {
    _lineMaxY += amount;
    _cursorY = _lineMaxY + style.itemSpacingY;
  }

  /// Draws a horizontal divider line.
  void separator() {
    final win = _currentWindow;
    if (win == null) return;
    final w = win.width - style.windowPadding * 2;
    final y = _lineMaxY + style.itemSpacingY;
    drawList.addLine(
      win.x + style.windowPadding,
      y,
      win.x + style.windowPadding + w,
      y,
      style.separator,
    );
    _lineMaxY = y + 2.0;
    _cursorY = _lineMaxY + style.itemSpacingY;
  }

  /// Displays plain text.
  void text(String content, {VoxColor? color}) {
    final c = color ?? style.text;
    final h = style.fontSize + 4.0;
    final w = content.length * (style.fontSize * 0.6); // approximate char width
    drawList.addText(
      content,
      _cursorX,
      _cursorY,
      color: c,
      size: style.fontSize,
    );
    _advanceLayout(w, h);
  }

  /// Displays a label: value pair on the same line.
  void labelValue(String label, String value, {VoxColor? valueColor}) {
    text('$label: ');
    sameLine(spacing: 4.0);
    text(value, color: valueColor ?? VoxColor.cyan);
  }

  /// Interactive push button. Returns `true` on the single frame it was clicked.
  bool button(String label, {double? width, double height = 24.0}) {
    final id = _getId(label);
    final win = _currentWindow;
    final w = width ??
        (win != null
            ? (win.width - style.windowPadding * 2)
            : label.length * 8.0 + 16.0);
    final h = height;

    final rect = VoxRect(_cursorX, _cursorY, w, h);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    _lastItemHovered = isHovered;
    if (isHovered) _hoveredId = id;

    final isClicked = isHovered && input.wasMouseClicked;
    if (isClicked) _activeId = id;

    final isPressed = (_activeId == id && input.isMouseDown && isHovered);

    VoxColor bg;
    if (isPressed) {
      bg = style.buttonActive;
    } else if (isHovered) {
      bg = style.buttonHover;
    } else {
      bg = style.buttonBg;
    }

    drawList.addRectFilled(
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      bg,
      cornerRadius: style.frameRounding,
    );

    // Center text in button
    final textW = label.length * (style.fontSize * 0.6);
    final tx = rect.x + math.max(0.0, (rect.width - textW) * 0.5);
    final ty = rect.y + (rect.height - style.fontSize) * 0.5;
    drawList.addText(
      label,
      tx,
      ty,
      color: style.text,
      size: style.fontSize,
    );

    _advanceLayout(w, h);
    return isHovered && input.wasMouseReleased && _activeId == id;
  }

  /// Interactive toggle checkbox. Returns updated boolean value.
  bool checkbox(String label, bool value) {
    final id = _getId(label);
    const boxSize = 16.0;
    final totalW = boxSize + 8.0 + (label.length * (style.fontSize * 0.6));
    const h = 20.0;

    final rect = VoxRect(_cursorX, _cursorY, totalW, h);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    _lastItemHovered = isHovered;
    if (isHovered) _hoveredId = id;

    var result = value;
    if (isHovered && input.wasMouseClicked) {
      result = !value;
    }

    // Box
    final boxRect = VoxRect(_cursorX, _cursorY + 2.0, boxSize, boxSize);
    drawList.addRectFilled(
      boxRect.x,
      boxRect.y,
      boxRect.width,
      boxRect.height,
      style.sliderBg,
      cornerRadius: style.frameRounding,
    );
    drawList.addRectOutline(
      boxRect.x,
      boxRect.y,
      boxRect.width,
      boxRect.height,
      isHovered ? style.sliderGrab : style.windowBorder,
      cornerRadius: style.frameRounding,
    );

    // Check mark
    if (value) {
      drawList.addRectFilled(
        boxRect.x + 3.0,
        boxRect.y + 3.0,
        boxRect.width - 6.0,
        boxRect.height - 6.0,
        style.checkMark,
        cornerRadius: 2.0,
      );
    }

    // Label text
    drawList.addText(
      label,
      _cursorX + boxSize + 8.0,
      _cursorY + 3.0,
      color: style.text,
      size: style.fontSize,
    );

    _advanceLayout(totalW, h);
    return result;
  }

  /// Floating-point draggable slider widget. Returns updated value.
  double sliderDouble(
    String label,
    double value, {
    double min = 0.0,
    double max = 1.0,
    double? width,
  }) {
    final id = _getId(label);
    final win = _currentWindow;
    final totalW = width ?? (win != null ? (win.width - style.windowPadding * 2) : 180.0);
    const h = 20.0;

    final rect = VoxRect(_cursorX, _cursorY, totalW, h);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    _lastItemHovered = isHovered;
    if (isHovered) _hoveredId = id;

    if (isHovered && input.wasMouseClicked) {
      _activeId = id;
    }

    var currentVal = value;
    if (_activeId == id && input.isMouseDown) {
      final t = ((input.mouseX - rect.x) / rect.width).clamp(0.0, 1.0);
      currentVal = min + t * (max - min);
    }

    // Background track
    drawList.addRectFilled(
      rect.x,
      rect.y + 2.0,
      rect.width,
      rect.height - 4.0,
      style.sliderBg,
      cornerRadius: style.frameRounding,
    );

    // Grab indicator
    final fraction = ((currentVal - min) / (max - min)).clamp(0.0, 1.0);
    final grabW = 12.0;
    final grabX = rect.x + fraction * (rect.width - grabW);
    drawList.addRectFilled(
      grabX,
      rect.y,
      grabW,
      rect.height,
      _activeId == id ? style.sliderGrabActive : style.sliderGrab,
      cornerRadius: style.frameRounding,
    );

    // Text label overlay (e.g. "Speed: 1.25")
    final display = '$label: ${currentVal.toStringAsFixed(2)}';
    drawList.addText(
      display,
      rect.x + 6.0,
      rect.y + 3.0,
      color: VoxColor.white,
      size: style.fontSize - 1.0,
    );

    _advanceLayout(totalW, h);
    return currentVal;
  }

  /// Integer draggable slider widget. Returns updated value.
  int sliderInt(
    String label,
    int value, {
    int min = 0,
    int max = 100,
    double? width,
  }) {
    final d = sliderDouble(
      label,
      value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      width: width,
    );
    return d.round();
  }

  /// Progress bar widget with optional label overlay.
  void progressBar(
    double fraction, {
    double? width,
    double height = 16.0,
    String? overlay,
  }) {
    final win = _currentWindow;
    final w = width ?? (win != null ? (win.width - style.windowPadding * 2) : 180.0);
    final h = height;

    final rect = VoxRect(_cursorX, _cursorY, w, h);
    drawList.addRectFilled(
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      style.sliderBg,
      cornerRadius: style.frameRounding,
    );

    final fillW = (rect.width * fraction.clamp(0.0, 1.0));
    if (fillW > 0) {
      drawList.addRectFilled(
        rect.x,
        rect.y,
        fillW,
        rect.height,
        style.sliderGrab,
        cornerRadius: style.frameRounding,
      );
    }

    final text = overlay ?? '${(fraction * 100).toStringAsFixed(0)}%';
    final textW = text.length * ((style.fontSize - 2) * 0.6);
    drawList.addText(
      text,
      rect.x + (rect.width - textW) * 0.5,
      rect.y + 2.0,
      color: VoxColor.white,
      size: style.fontSize - 2.0,
    );

    _advanceLayout(w, h);
  }

  /// Collapsing header foldout section. Returns `true` if expanded.
  bool collapsingHeader(String label, {bool defaultOpen = false}) {
    final id = _getId(label);
    final win = _currentWindow;
    final w = win != null ? (win.width - style.windowPadding * 2) : 200.0;
    const h = 22.0;

    var isOpen = _collapsingStates.putIfAbsent(id, () => defaultOpen);

    final rect = VoxRect(_cursorX, _cursorY, w, h);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    if (isHovered && input.wasMouseClicked) {
      isOpen = !isOpen;
      _collapsingStates[id] = isOpen;
    }

    drawList.addRectFilled(
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      isHovered ? style.buttonHover : style.headerBg,
      cornerRadius: style.frameRounding,
    );

    final icon = isOpen ? 'v' : '>';
    drawList.addText(
      '$icon $label',
      rect.x + 8.0,
      rect.y + 4.0,
      color: style.titleBarText,
      size: style.fontSize,
    );

    _advanceLayout(w, h);
    return isOpen;
  }

  /// Displays a floating tooltip box near the mouse cursor if the previous widget was hovered.
  void tooltip(String text) {
    if (!_lastItemHovered) return;
    const padding = 6.0;
    final textW = text.length * (style.fontSize * 0.6);
    final textH = style.fontSize + 4.0;
    final w = textW + padding * 2;
    final h = textH + padding * 2;
    final x = input.mouseX + 14.0;
    final y = input.mouseY + 14.0;

    drawList.addRectFilled(x, y, w, h, style.tooltipBg, cornerRadius: style.frameRounding);
    drawList.addRectOutline(x, y, w, h, style.tooltipBorder, cornerRadius: style.frameRounding);
    drawList.addText(text, x + padding, y + padding, color: style.text, size: style.fontSize);
  }

  /// Interactive single-line text input widget. Returns the updated string.
  String inputText(
    String label,
    String value, {
    int? maxChars,
    bool password = false,
    double? width,
    double height = 22.0,
  }) {
    final id = _getId(label);
    final win = _currentWindow;
    final totalW = width ?? (win != null ? (win.width - style.windowPadding * 2) : 200.0);
    final h = height;

    final rect = VoxRect(_cursorX, _cursorY, totalW, h);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    _lastItemHovered = isHovered;

    if (isHovered && input.wasMouseClicked) {
      _focusedInputId = id;
    } else if (input.wasMouseClicked && !isHovered && _focusedInputId == id) {
      _focusedInputId = 0;
    }

    var currentVal = value;
    final isFocused = _focusedInputId == id;

    if (isFocused) {
      // Process newly typed characters
      if (input.textInput.isNotEmpty) {
        if (maxChars == null || currentVal.length + input.textInput.length <= maxChars) {
          currentVal += input.textInput;
        }
      }

      // Handle Backspace
      if (input.keysPressed.contains('Backspace') && currentVal.isNotEmpty) {
        currentVal = currentVal.substring(0, currentVal.length - 1);
      }

      // Blur on Enter or Escape
      if (input.keysPressed.contains('Enter') || input.keysPressed.contains('Escape')) {
        _focusedInputId = 0;
      }
    }

    // Background
    drawList.addRectFilled(rect.x, rect.y, rect.width, rect.height, style.inputTextBg, cornerRadius: style.frameRounding);
    drawList.addRectOutline(
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      isFocused ? style.inputTextActive : (isHovered ? style.sliderGrab : style.inputTextBorder),
      cornerRadius: style.frameRounding,
    );

    // Text content
    final displayText = password ? '*' * currentVal.length : currentVal;
    drawList.addText(
      displayText,
      rect.x + 6.0,
      rect.y + (h - style.fontSize) * 0.5,
      color: style.text,
      size: style.fontSize,
    );

    // Blinking cursor when focused
    if (isFocused && (_frameIndex % 60 < 30)) {
      final textW = displayText.length * (style.fontSize * 0.6);
      final cursorX = rect.x + 6.0 + textW;
      final cursorY = rect.y + 4.0;
      drawList.addLine(cursorX, cursorY, cursorX, cursorY + h - 8.0, style.inputTextActive, thickness: 1.5);
    }

    _advanceLayout(totalW, h);
    return currentVal;
  }

  /// Interactive color swatch and RGBA sliders. Returns updated [VoxColor].
  VoxColor colorEdit4(String label, VoxColor color) {
    text('$label:');
    sameLine(spacing: 8.0);

    // Swatch box
    const swatchSize = 18.0;
    final swatchRect = VoxRect(_cursorX, _cursorY, swatchSize, swatchSize);
    drawList.addRectFilled(swatchRect.x, swatchRect.y, swatchRect.width, swatchRect.height, color, cornerRadius: 3.0);
    drawList.addRectOutline(swatchRect.x, swatchRect.y, swatchRect.width, swatchRect.height, style.windowBorder, cornerRadius: 3.0);
    _advanceLayout(swatchSize, swatchSize);

    sameLine(spacing: 6.0);
    final r = sliderInt('R##$label', color.r, min: 0, max: 255, width: 60.0);
    sameLine(spacing: 4.0);
    final g = sliderInt('G##$label', color.g, min: 0, max: 255, width: 60.0);
    sameLine(spacing: 4.0);
    final b = sliderInt('B##$label', color.b, min: 0, max: 255, width: 60.0);
    sameLine(spacing: 4.0);
    final a = sliderInt('A##$label', color.a, min: 0, max: 255, width: 60.0);

    return VoxColor(r, g, b, a);
  }

  /// Interactive color swatch and RGB sliders. Returns updated [VoxColor].
  VoxColor colorEdit3(String label, VoxColor color) {
    final c4 = colorEdit4(label, color.withAlpha(255));
    return VoxColor(c4.r, c4.g, c4.b, 255);
  }

  /// Dropdown combo selector. Returns updated [selectedIndex].
  int combo(String label, int selectedIndex, List<String> items, {double? width}) {
    final id = _getId(label);
    final win = _currentWindow;
    final totalW = width ?? (win != null ? (win.width - style.windowPadding * 2) : 200.0);
    const h = 22.0;

    final rect = VoxRect(_cursorX, _cursorY, totalW, h);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    _lastItemHovered = isHovered;

    var isOpen = _comboStates[id] ?? false;
    if (isHovered && input.wasMouseClicked) {
      isOpen = !isOpen;
      _comboStates[id] = isOpen;
    }

    var resultIndex = selectedIndex;

    // Header box
    drawList.addRectFilled(rect.x, rect.y, rect.width, rect.height, style.buttonBg, cornerRadius: style.frameRounding);
    drawList.addRectOutline(
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      isHovered || isOpen ? style.sliderGrab : style.windowBorder,
      cornerRadius: style.frameRounding,
    );

    final selectedText = (selectedIndex >= 0 && selectedIndex < items.length) ? items[selectedIndex] : '';
    drawList.addText(selectedText, rect.x + 8.0, rect.y + 4.0, color: style.text, size: style.fontSize);
    drawList.addText('v', rect.right - 16.0, rect.y + 4.0, color: style.titleBarText, size: style.fontSize - 2.0);

    _advanceLayout(totalW, h);

    // Dropdown list popup
    if (isOpen) {
      const itemH = 20.0;
      final popupH = items.length * itemH;
      final popupY = rect.bottom + 2.0;

      drawList.addRectFilled(rect.x, popupY, rect.width, popupH, style.popupBg, cornerRadius: style.frameRounding);
      drawList.addRectOutline(rect.x, popupY, rect.width, popupH, style.popupBorder, cornerRadius: style.frameRounding);

      for (int i = 0; i < items.length; i++) {
        final itemRect = VoxRect(rect.x, popupY + i * itemH, rect.width, itemH);
        final itemHovered = itemRect.contains(input.mouseX, input.mouseY);

        if (itemHovered) {
          drawList.addRectFilled(itemRect.x, itemRect.y, itemRect.width, itemRect.height, style.buttonHover);
        }
        if (itemHovered && input.wasMouseClicked) {
          resultIndex = i;
          _comboStates[id] = false;
        }

        drawList.addText(
          items[i],
          itemRect.x + 8.0,
          itemRect.y + 3.0,
          color: i == selectedIndex ? style.checkMark : style.text,
          size: style.fontSize,
        );
      }
    }

    return resultIndex;
  }

  /// Begins a horizontal tab bar container.
  bool beginTabBar(String id) {
    _currentTabBarId = _getId(id);
    return true;
  }

  void endTabBar() {
    _currentTabBarId = 0;
  }

  /// Begins a single tab item. Returns `true` if this tab is active and its content should be rendered.
  bool beginTabItem(String label) {
    final barId = _currentTabBarId;
    final activeTab = _tabBarActiveTabs.putIfAbsent(barId, () => label);
    final isActive = activeTab == label;

    final tabW = label.length * (style.fontSize * 0.6) + 20.0;
    const tabH = 24.0;

    final rect = VoxRect(_cursorX, _cursorY, tabW, tabH);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    _lastItemHovered = isHovered;

    if (isHovered && input.wasMouseClicked) {
      _tabBarActiveTabs[barId] = label;
    }

    final bg = isActive ? style.tabActive : (isHovered ? style.tabHover : style.tabBg);
    drawList.addRectFilled(rect.x, rect.y, rect.width, rect.height, bg, cornerRadius: style.frameRounding);
    drawList.addText(
      label,
      rect.x + 10.0,
      rect.y + 5.0,
      color: isActive ? VoxColor.white : style.text,
      size: style.fontSize,
    );

    // Position next tab horizontally
    sameLine(spacing: 4.0);
    _advanceLayout(tabW, tabH);
    return isActive;
  }

  void endTabItem() {
    // Closes tab item scope
  }

  /// Collapsible hierarchical tree node. Returns `true` if open and indents content.
  bool treeNode(String label, {bool defaultOpen = false}) {
    final id = _getId(label);
    const h = 20.0;
    final w = (label.length + 3) * (style.fontSize * 0.6) + 16.0;

    var isOpen = _collapsingStates.putIfAbsent(id, () => defaultOpen);

    final rect = VoxRect(_cursorX, _cursorY, w, h);
    final isHovered = rect.contains(input.mouseX, input.mouseY);
    _lastItemHovered = isHovered;

    if (isHovered && input.wasMouseClicked) {
      isOpen = !isOpen;
      _collapsingStates[id] = isOpen;
    }

    if (isHovered) {
      drawList.addRectFilled(rect.x, rect.y, rect.width, rect.height, style.buttonHover, cornerRadius: 2.0);
    }

    final icon = isOpen ? 'v' : '>';
    drawList.addText(
      '$icon $label',
      rect.x + 2.0,
      rect.y + 2.0,
      color: isHovered ? VoxColor.white : style.text,
      size: style.fontSize,
    );

    _advanceLayout(w, h);
    if (isOpen) {
      indent(16.0);
      return true;
    }
    return false;
  }

  /// Closes an open [treeNode] and restores indentation.
  void treePop() {
    unindent(16.0);
  }

  /// Rolling line graph plot for profiling metrics, frame times, and historical data.
  void plotLines(
    String label,
    List<double> values, {
    double? min,
    double? max,
    double? width,
    double height = 40.0,
    String? overlayText,
  }) {
    final win = _currentWindow;
    final totalW = width ?? (win != null ? (win.width - style.windowPadding * 2) : 200.0);
    final h = height;

    final rect = VoxRect(_cursorX, _cursorY, totalW, h);
    drawList.addRectFilled(rect.x, rect.y, rect.width, rect.height, style.plotBg, cornerRadius: style.frameRounding);
    drawList.addRectOutline(rect.x, rect.y, rect.width, rect.height, style.windowBorder, cornerRadius: style.frameRounding);

    if (values.length >= 2) {
      double minVal = min ?? values.reduce(math.min);
      double maxVal = max ?? values.reduce(math.max);
      if (maxVal - minVal < 1e-4) maxVal = minVal + 1.0;

      final stepX = rect.width / (values.length - 1);
      for (int i = 0; i < values.length - 1; i++) {
        final t1 = ((values[i] - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);
        final t2 = ((values[i + 1] - minVal) / (maxVal - minVal)).clamp(0.0, 1.0);

        final x1 = rect.x + i * stepX;
        final y1 = rect.bottom - (t1 * rect.height);
        final x2 = rect.x + (i + 1) * stepX;
        final y2 = rect.bottom - (t2 * rect.height);

        drawList.addLine(x1, y1, x2, y2, style.plotLine, thickness: 1.5);
      }
    }

    final overlay = overlayText ?? '$label: ${values.isNotEmpty ? values.last.toStringAsFixed(1) : ""}';
    drawList.addText(overlay, rect.x + 6.0, rect.y + 4.0, color: VoxColor.white, size: style.fontSize - 2.0);

    _advanceLayout(totalW, h);
  }

  /// Opens a popup dialog with identifier [id].
  void openPopup(String id) {
    _openPopups.add(_getId(id));
  }

  /// Closes an open popup with identifier [id].
  void closePopup(String id) {
    _openPopups.remove(_getId(id));
  }

  /// Begins a modal or contextual popup. Returns `true` if open.
  bool beginPopup(String id, {double width = 200.0, double height = 150.0}) {
    final popupId = _getId(id);
    if (!_openPopups.contains(popupId)) return false;

    // Center on screen or near mouse
    final x = math.max(10.0, input.mouseX - width * 0.5);
    final y = math.max(10.0, input.mouseY - 20.0);

    drawList.addRectFilled(x, y, width, height, style.popupBg, cornerRadius: style.windowRounding);
    drawList.addRectOutline(x, y, width, height, style.popupBorder, cornerRadius: style.windowRounding);

    _cursorX = x + style.windowPadding;
    _cursorY = y + style.windowPadding;
    _lineMaxY = _cursorY;
    return true;
  }

  void endPopup() {
    // Closes popup layout
  }
}

/// Global convenience singleton instance for [VoxUiContext].
final voxui = VoxUiContext();

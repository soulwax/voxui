import 'package:test/test.dart';
import 'package:voxui/voxui.dart';

void main() {
  group('voxui - Core Immediate Mode GUI Suite', () {
    test('VoxColor & VoxRect calculations', () {
      final c1 = VoxColor.fromHex(0xFF00AA);
      expect(c1.r, equals(0xFF));
      expect(c1.g, equals(0x00));
      expect(c1.b, equals(0xAA));
      expect(c1.a, equals(255));

      final c2 = VoxColor.fromHex(0x11223344);
      expect(c2.r, equals(0x11));
      expect(c2.g, equals(0x22));
      expect(c2.b, equals(0x33));
      expect(c2.a, equals(0x44));

      const r1 = VoxRect(10, 10, 100, 100);
      expect(r1.contains(50, 50), isTrue);
      expect(r1.contains(5, 5), isFalse);

      const r2 = VoxRect(50, 50, 100, 100);
      expect(r1.intersects(r2), isTrue);

      final intersection = r1.intersect(r2);
      expect(intersection.x, equals(50));
      expect(intersection.y, equals(50));
      expect(intersection.width, equals(60));
      expect(intersection.height, equals(60));
    });

    test('Immediate window rendering and draw list recording', () {
      final ui = VoxUiContext();
      final input = VoxInput(mouseX: 0, mouseY: 0);
      ui.beginFrame(input);

      final open = ui.beginWindow('Engine Diagnostics', x: 20, y: 30, width: 250, height: 150);
      expect(open, isTrue);

      ui.text('Frame Rate: 60 FPS');
      ui.separator();
      ui.spacing(10);
      ui.progressBar(0.75, overlay: '75% Health');

      ui.endWindow();
      final dl = ui.endFrame();

      expect(dl.commands, isNotEmpty);
      final hasTitle = dl.commands.any(
        (cmd) => cmd.type == DrawCmdType.text && cmd.text == 'Engine Diagnostics',
      );
      expect(hasTitle, isTrue);

      final hasFpsText = dl.commands.any(
        (cmd) => cmd.type == DrawCmdType.text && cmd.text == 'Frame Rate: 60 FPS',
      );
      expect(hasFpsText, isTrue);
    });

    test('Interactive push button and state transitions', () {
      final ui = VoxUiContext();

      // Frame 1: Pointer outside button
      var input = VoxInput(mouseX: 0, mouseY: 0, isMouseDown: false);
      ui.beginFrame(input);
      ui.beginWindow('Controls', x: 0, y: 0, width: 200, height: 200);
      var clicked = ui.button('Spawn Asteroid');
      ui.endWindow();
      ui.endFrame();
      expect(clicked, isFalse);

      // Frame 2: Mouse down over button
      // Window title bar is 26px + 10px pad = button is around y ~ 36
      input = VoxInput(
        mouseX: 50,
        mouseY: 45,
        isMouseDown: true,
        wasMouseClicked: true,
      );
      ui.beginFrame(input);
      ui.beginWindow('Controls', x: 0, y: 0, width: 200, height: 200);
      clicked = ui.button('Spawn Asteroid');
      ui.endWindow();
      ui.endFrame();
      expect(clicked, isFalse); // not released yet

      // Frame 3: Mouse released over button -> triggers click!
      input = VoxInput(
        mouseX: 50,
        mouseY: 45,
        isMouseDown: false,
        wasMouseReleased: true,
      );
      ui.beginFrame(input);
      ui.beginWindow('Controls', x: 0, y: 0, width: 200, height: 200);
      clicked = ui.button('Spawn Asteroid');
      ui.endWindow();
      ui.endFrame();
      expect(clicked, isTrue);
    });

    test('Checkbox and Slider interaction', () {
      final ui = VoxUiContext();

      // Checkbox toggle: mouse over checkbox (y ~ 45 inside window)
      var input = VoxInput(
        mouseX: 25,
        mouseY: 45,
        wasMouseClicked: true,
        isMouseDown: true,
      );
      ui.beginFrame(input);
      ui.beginWindow('Settings', x: 0, y: 0, width: 200, height: 200);
      final wireframe = ui.checkbox('Wireframe Mode', false);
      expect(wireframe, isTrue);
      ui.endWindow();
      ui.endFrame();

      // Slider double adjustment:
      // Inside window: titleBar(26) + padding(10) = cursor at y=36.
      // Mouse at x=100 (50% of 200px width), y=45
      input = VoxInput(
        mouseX: 100,
        mouseY: 45,
        isMouseDown: true,
        wasMouseClicked: true,
      );
      ui.beginFrame(input);
      ui.beginWindow('Settings', x: 0, y: 0, width: 200, height: 200);
      final speed = ui.sliderDouble('Speed', 0.0, min: 0.0, max: 10.0, width: 200.0);
      expect(speed, inInclusiveRange(4.0, 6.0));
      ui.endWindow();
      ui.endFrame();
    });

    test('inputText receives typing and handles backspace', () {
      final ui = VoxUiContext();

      // Click to focus input box
      var input = VoxInput(mouseX: 50, mouseY: 45, wasMouseClicked: true);
      ui.beginFrame(input);
      ui.beginWindow('NameEditor', x: 0, y: 0, width: 200, height: 200);
      var text = ui.inputText('Name', 'Player');
      ui.endWindow();
      ui.endFrame();

      // Frame 2: Type '1'
      input = VoxInput(mouseX: 50, mouseY: 45, textInput: '1');
      ui.beginFrame(input);
      ui.beginWindow('NameEditor', x: 0, y: 0, width: 200, height: 200);
      text = ui.inputText('Name', text);
      expect(text, equals('Player1'));
      ui.endWindow();
      ui.endFrame();

      // Frame 3: Backspace
      input = VoxInput(mouseX: 50, mouseY: 45, keysPressed: {'Backspace'});
      ui.beginFrame(input);
      ui.beginWindow('NameEditor', x: 0, y: 0, width: 200, height: 200);
      text = ui.inputText('Name', text);
      expect(text, equals('Player'));
      ui.endWindow();
      ui.endFrame();
    });

    test('combo dropdown selects item', () {
      final ui = VoxUiContext();

      // Frame 1: Click combo to open dropdown
      var input = VoxInput(mouseX: 50, mouseY: 45, wasMouseClicked: true);
      ui.beginFrame(input);
      ui.beginWindow('Weapons', x: 0, y: 0, width: 200, height: 200);
      var selected = ui.combo('Weapon', 0, ['Sword', 'Bow', 'Staff']);
      ui.endWindow();
      ui.endFrame();

      // Frame 2: Click second item ('Bow', y ~ 45 + 22 + 20)
      input = VoxInput(mouseX: 50, mouseY: 85, wasMouseClicked: true);
      ui.beginFrame(input);
      ui.beginWindow('Weapons', x: 0, y: 0, width: 200, height: 200);
      selected = ui.combo('Weapon', selected, ['Sword', 'Bow', 'Staff']);
      expect(selected, equals(1)); // 'Bow' selected
      ui.endWindow();
      ui.endFrame();
    });

    test('TabBar switches active tab item', () {
      final ui = VoxUiContext();

      var input = VoxInput(mouseX: 0, mouseY: 0);
      ui.beginFrame(input);
      ui.beginWindow('Tabs', x: 0, y: 0, width: 200, height: 200);
      ui.beginTabBar('MainTabs');
      final isTab1 = ui.beginTabItem('General');
      ui.endTabItem();
      final isTab2 = ui.beginTabItem('Audio');
      ui.endTabItem();
      ui.endTabBar();
      ui.endWindow();
      ui.endFrame();

      expect(isTab1, isTrue); // First tab default active
      expect(isTab2, isFalse);
    });

    test('treeNode indents and plotLines records lines', () {
      final ui = VoxUiContext();

      var input = VoxInput(mouseX: 0, mouseY: 0);
      ui.beginFrame(input);
      ui.beginWindow('SceneView', x: 0, y: 0, width: 200, height: 200);
      final isTreeOpen = ui.treeNode('RootNode', defaultOpen: true);
      expect(isTreeOpen, isTrue);

      ui.plotLines('FPS', [58.0, 59.0, 60.0, 60.0, 61.0]);
      ui.treePop();

      ui.endWindow();
      final dl = ui.endFrame();

      final hasPlotLine = dl.commands.any((cmd) => cmd.type == DrawCmdType.line);
      expect(hasPlotLine, isTrue);
    });

    test('Collapsing header foldout toggle', () {
      final ui = VoxUiContext();

      var input = VoxInput(mouseX: 50, mouseY: 45, wasMouseClicked: true);
      ui.beginFrame(input);
      ui.beginWindow('Inspector', x: 0, y: 0, width: 200, height: 200);
      final isOpen1 = ui.collapsingHeader('Transform', defaultOpen: false);
      expect(isOpen1, isTrue); // toggled open from click

      // Next frame without click -> stays open
      input = VoxInput(mouseX: 0, mouseY: 0);
      ui.beginFrame(input);
      final isOpen2 = ui.collapsingHeader('Transform', defaultOpen: false);
      expect(isOpen2, isTrue);

      ui.endWindow();
      ui.endFrame();
    });

    test('inputText receives typing and handles backspace', () {
      final ui = VoxUiContext();

      // Click to focus input box
      var input = VoxInput(mouseX: 50, mouseY: 45, wasMouseClicked: true);
      ui.beginFrame(input);
      ui.beginWindow('NameEditor', x: 0, y: 0, width: 200, height: 200);
      var text = ui.inputText('Name', 'Player');
      ui.endWindow();
      ui.endFrame();

      // Frame 2: Type '1'
      input = VoxInput(mouseX: 50, mouseY: 45, textInput: '1');
      ui.beginFrame(input);
      ui.beginWindow('NameEditor', x: 0, y: 0, width: 200, height: 200);
      text = ui.inputText('Name', text);
      expect(text, equals('Player1'));
      ui.endWindow();
      ui.endFrame();

      // Frame 3: Backspace
      input = VoxInput(mouseX: 50, mouseY: 45, keysPressed: {'Backspace'});
      ui.beginFrame(input);
      ui.beginWindow('NameEditor', x: 0, y: 0, width: 200, height: 200);
      text = ui.inputText('Name', text);
      expect(text, equals('Player'));
      ui.endWindow();
      ui.endFrame();
    });

    test('combo dropdown selects item', () {
      final ui = VoxUiContext();

      // Frame 1: Click combo to open dropdown
      var input = VoxInput(mouseX: 50, mouseY: 45, wasMouseClicked: true);
      ui.beginFrame(input);
      ui.beginWindow('Weapons', x: 0, y: 0, width: 200, height: 200);
      var selected = ui.combo('Weapon', 0, ['Sword', 'Bow', 'Staff']);
      ui.endWindow();
      ui.endFrame();

      // Frame 2: Click second item ('Bow', y ~ 45 + 22 + 20)
      input = VoxInput(mouseX: 50, mouseY: 85, wasMouseClicked: true);
      ui.beginFrame(input);
      ui.beginWindow('Weapons', x: 0, y: 0, width: 200, height: 200);
      selected = ui.combo('Weapon', selected, ['Sword', 'Bow', 'Staff']);
      expect(selected, equals(1)); // 'Bow' selected
      ui.endWindow();
      ui.endFrame();
    });

    test('TabBar switches active tab item', () {
      final ui = VoxUiContext();

      var input = VoxInput(mouseX: 0, mouseY: 0);
      ui.beginFrame(input);
      ui.beginWindow('Tabs', x: 0, y: 0, width: 200, height: 200);
      ui.beginTabBar('MainTabs');
      final isTab1 = ui.beginTabItem('General');
      ui.endTabItem();
      final isTab2 = ui.beginTabItem('Audio');
      ui.endTabItem();
      ui.endTabBar();
      ui.endWindow();
      ui.endFrame();

      expect(isTab1, isTrue); // First tab default active
      expect(isTab2, isFalse);
    });

    test('treeNode indents and plotLines records lines', () {
      final ui = VoxUiContext();

      var input = VoxInput(mouseX: 0, mouseY: 0);
      ui.beginFrame(input);
      ui.beginWindow('SceneView', x: 0, y: 0, width: 200, height: 200);
      final isTreeOpen = ui.treeNode('RootNode', defaultOpen: true);
      expect(isTreeOpen, isTrue);

      ui.plotLines('FPS', [58.0, 59.0, 60.0, 60.0, 61.0]);
      ui.treePop();

      ui.endWindow();
      final dl = ui.endFrame();

      final hasPlotLine = dl.commands.any((cmd) => cmd.type == DrawCmdType.line);
      expect(hasPlotLine, isTrue);
    });
  });
}

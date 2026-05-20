import 'package:build_tool/domain/models/custom_command.dart';
import 'package:build_tool/ui/dialogs/custom_command_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns CustomCommand with label and command on save',
      (tester) async {
    CustomCommand? captured;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      return TextButton(
        onPressed: () async {
          captured = await showDialog<CustomCommand>(
            context: c,
            builder: (_) => const CustomCommandDialog(initial: null),
          );
        },
        child: const Text('Open'),
      );
    })));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('label-field')), 'Deploy');
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('command-field')), 'firebase deploy');
    await tester.pump(); // flush setState so Save button becomes enabled
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(captured?.label, 'Deploy');
    expect(captured?.command, 'firebase deploy');
  });

  testWidgets('Save disabled when fields empty', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      return TextButton(
        onPressed: () => showDialog<CustomCommand>(
            context: c,
            builder: (_) => const CustomCommandDialog(initial: null)),
        child: const Text('Open'),
      );
    })));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final saveBtn = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(saveBtn.onPressed, isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _padding = ValueNotifier<EdgeInsets>(EdgeInsets.zero); // physical px

void listenForDisplayCutouts() {
  const BasicMessageChannel<Object?>(
    'flutter-sfos/display_cutouts',
    JSONMessageCodec(),
  ).setMessageHandler((message) async {
    final p = (message! as Map)['padding'] as Map;
    double v(String k) => (p[k] as num).toDouble();
    _padding.value = EdgeInsets.fromLTRB(
      v('left'),
      v('top'),
      v('right'),
      v('bottom'),
    );
    return null;
  });
}

Widget cutoutPadding(BuildContext context, Widget? child) {
  return ValueListenableBuilder<EdgeInsets>(
    valueListenable: _padding,
    builder: (context, padding, _) {
      final mq = MediaQuery.of(context);
      final extra = padding / mq.devicePixelRatio;
      return MediaQuery(
        data: mq.copyWith(
          padding: mq.padding + extra,
          viewPadding: mq.viewPadding + extra,
        ),
        child: child!,
      );
    },
  );
}

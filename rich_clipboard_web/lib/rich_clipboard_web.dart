import 'dart:html';
import 'dart:js';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:rich_clipboard_platform_interface/rich_clipboard_platform_interface.dart';

const _kMimeTextPlain = 'text/plain';
const _kMimeTextHtml = 'text/html';

bool _detectClipboardApi() {
  final clipboard = window.navigator.clipboard;
  if (clipboard == null) {
    return false;
  }
  for (final methodName in ['read', 'write']) {
    final method = getProperty(clipboard, methodName);
    if (method == null) {
      return false;
    }
  }

  return true;
}

/// The web implementation of [RichClipboard].
class RichClipboardWeb extends RichClipboardPlatform {
  /// Registers the implementation.
  static void registerWith(Registrar registrar) {
    if (!_detectClipboardApi()) {
      return;
    }
    RichClipboardPlatform.instance = RichClipboardWeb();
  }

  @override
  void initOnPasteWeb(void Function(RichClipboardData data) onPaste) {
    window.document.onPaste.listen((e) {
      try {
        print('LL:: _ClipboardProcessStatus | onPaste.listen');
        e.preventDefault();
        final datas = e.clipboardData;
        final mapData = <String, String?>{};

        for (final type in datas?.types ?? <String>[]) {
          print('LL:: type: $type');
          mapData.addEntries({type: datas?.getData(type)}.entries);
        }

        onPaste(RichClipboardData.fromMap(mapData));
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  @override
  Future<List<String>> getAvailableTypes() async {
    final clipboard = window.navigator.clipboard as _Clipboard?;
    if (clipboard == null) {
      return [];
    }

    final data = await clipboard.read();
    if (data.isEmpty) {
      return [];
    }
    return data.first.types;
  }

  @override
  Future<RichClipboardData> getData() async {
    final clipboard = window.navigator.clipboard as _Clipboard?;
    if (clipboard == null) {
      return const RichClipboardData();
    }

    final contents = await clipboard.read();
    if (contents.isEmpty) {
      return const RichClipboardData();
    }

    final item = contents.first;
    final availableTypes = item.types;

    String? text;
    String? html;
    if (availableTypes.contains(_kMimeTextPlain)) {
      final textBlob = await item.getType('text/plain');
      text = await textBlob.text();
    }
    if (availableTypes.contains(_kMimeTextHtml)) {
      final htmlBlob = await item.getType('text/html');
      html = await htmlBlob.text();
    }

    return RichClipboardData(
      text: text,
      html: html,
    );
  }

  @override
  Future<void> setData(RichClipboardData data) async {
    window.document.onCopy.listen((e) {
      e.preventDefault();

      for (final item in data.toMap().entries) {
        final key = item.key;
        final value = item.value;

        if (value != null) {
          e.clipboardData!.setData(key, value);
        }
      }
      e.clipboardData;
    });
    window.document.execCommand('copy');
  }
}

@JS('Blob')
@staticInterop
extension _BlobText on Blob {
  @JS('text')
  external dynamic _text();
  Future<String> text() => promiseToFuture<String>(_text());
}

@JS('ClipboardItem')
@staticInterop
class _ClipboardItem {
  external factory _ClipboardItem(dynamic args);
}

extension _ClipboardItemImpl on _ClipboardItem {
  @JS('getType')
  external dynamic _getType(String mimeType);
  Future<Blob> getType(String mimeType) =>
      promiseToFuture<Blob>(_getType(mimeType));

  @JS('types')
  external List<dynamic> get _types;
  List<String> get types => _types.cast<String>();
}

@JS('Clipboard')
@staticInterop
class _Clipboard {}

extension _ClipboardImpl on _Clipboard {
  @JS('read')
  external dynamic _read();
  Future<List<_ClipboardItem>> read() => promiseToFuture<List<dynamic>>(_read())
      .then((list) => list.cast<_ClipboardItem>());

  @JS('write')
  external dynamic _write(List<_ClipboardItem> items);
  Future<void> write(List<_ClipboardItem> items) =>
      promiseToFuture(_write(items));
}

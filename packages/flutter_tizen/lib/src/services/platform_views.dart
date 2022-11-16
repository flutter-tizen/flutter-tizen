// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Source: [_AndroidViewState] in flutter/src/services/platform_views.dart
enum _TizenViewState {
  waitingForSize,
  creating,
  created,
  disposed,
}

/// Controls a Tizen view that is composed using a GL texture.
//
/// Source: [AndroidViewController] in flutter/src/services/platform_views.dart
abstract class TizenViewController extends PlatformViewController {
  TizenViewController._({
    required this.viewId,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
  })  : assert(viewId != null),
        assert(viewType != null),
        assert(layoutDirection != null),
        assert(creationParams == null || creationParamsCodec != null),
        _viewType = viewType,
        _layoutDirection = layoutDirection,
        _creationParams = creationParams,
        _creationParamsCodec = creationParamsCodec;

  @override
  final int viewId;

  final String _viewType;

  TextDirection _layoutDirection;

  _TizenViewState _state = _TizenViewState.waitingForSize;

  final dynamic _creationParams;

  final MessageCodec<dynamic>? _creationParamsCodec;

  final List<PlatformViewCreatedCallback> _platformViewCreatedCallbacks =
      <PlatformViewCreatedCallback>[];

  Future<void> _sendDisposeMessage();

  bool get _createRequiresSize;

  Future<void> _sendCreateMessage({required covariant Size? size});

  Future<Size> _sendResizeMessage(Size size);

  @override
  Future<void> create({Size? size}) async {
    assert(_state != _TizenViewState.disposed,
        'trying to create a disposed Tizen view');
    assert(_state == _TizenViewState.waitingForSize,
        'Tizen view is already sized. View id: $viewId');

    if (_createRequiresSize && size == null) {
      // Wait for a setSize call.
      return;
    }

    _state = _TizenViewState.creating;
    await _sendCreateMessage(size: size);
    _state = _TizenViewState.created;

    for (final PlatformViewCreatedCallback callback
        in _platformViewCreatedCallbacks) {
      callback(viewId);
    }
  }

  Future<Size> setSize(Size size) async {
    assert(_state != _TizenViewState.disposed,
        'Tizen view is disposed. View id: $viewId');
    if (_state == _TizenViewState.waitingForSize) {
      // Either `create` hasn't been called, or it couldn't run due to missing
      // size information, so create the view now.
      await create(size: size);
      return size;
    } else {
      return _sendResizeMessage(size);
    }
  }

  Future<void> setOffset(Offset off);

  int? get textureId;

  Future<void> sendTouchEvent(Map<String, dynamic> args) async {
    await SystemChannels.platform_views.invokeMethod<dynamic>('touch', args);
  }

  void addOnPlatformViewCreatedListener(PlatformViewCreatedCallback listener) {
    assert(listener != null);
    assert(_state != _TizenViewState.disposed);
    _platformViewCreatedCallbacks.add(listener);
  }

  void removeOnPlatformViewCreatedListener(
      PlatformViewCreatedCallback listener) {
    assert(_state != _TizenViewState.disposed);
    _platformViewCreatedCallbacks.remove(listener);
  }

  @visibleForTesting
  List<PlatformViewCreatedCallback> get createdCallbacks =>
      _platformViewCreatedCallbacks;

  Future<void> setLayoutDirection(TextDirection layoutDirection) async {
    assert(_state != _TizenViewState.disposed,
        'trying to set a layout direction for a disposed UIView. View id: $viewId');

    if (layoutDirection == _layoutDirection) {
      return;
    }

    assert(layoutDirection != null);
    _layoutDirection = layoutDirection;

    if (_state == _TizenViewState.waitingForSize) {
      return;
    }

    await SystemChannels.platform_views
        .invokeMethod<void>('setDirection', <String, dynamic>{
      'id': viewId,
      'direction': layoutDirection == TextDirection.ltr ? 0 : 1,
    });
  }

  @override
  Future<void> dispatchPointerEvent(PointerEvent event) async {
    if (event is PointerHoverEvent) {
      return;
    }

    int eventType = 0;
    if (event is PointerDownEvent) {
      eventType = 0;
    } else if (event is PointerMoveEvent) {
      eventType = 1;
    } else if (event is PointerUpEvent) {
      eventType = 2;
    } else {
      throw UnimplementedError('Not Implemented');
    }

    final Map<String, dynamic> args = <String, dynamic>{
      'id': viewId,
      'event': <dynamic>[
        eventType,
        event.buttons,
        event.localPosition.dx,
        event.localPosition.dy,
        event.localDelta.dx,
        event.localDelta.dy,
      ]
    };
    await sendTouchEvent(args);
  }

  @override
  Future<void> clearFocus() {
    if (_state != _TizenViewState.created) {
      return Future<void>.value();
    }
    return SystemChannels.platform_views
        .invokeMethod<void>('clearFocus', viewId);
  }

  @override
  Future<void> dispose() async {
    if (_state == _TizenViewState.creating ||
        _state == _TizenViewState.created) {
      await _sendDisposeMessage();
    }
    _platformViewCreatedCallbacks.clear();
    _state = _TizenViewState.disposed;
    PlatformViewsServiceTizen._instance._focusCallbacks.remove(viewId);
  }
}

/// Controls a Tizen view that is composed using a GL texture.
///
/// This controller is created from the [PlatformViewsServiceTizen.initTizenView] factory,
///
/// Source: [TextureAndroidViewController] in flutter/src/services/platform_views.dart
class TextureTizenViewController extends TizenViewController {
  TextureTizenViewController._({
    required super.viewId,
    required super.viewType,
    required super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
  }) : super._();

  int? _textureId;

  @override
  int? get textureId => _textureId;

  Offset _off = Offset.zero;

  @override
  Future<Size> _sendResizeMessage(Size size) async {
    assert(_state != _TizenViewState.waitingForSize,
        'Tizen view must have an initial size. View id: $viewId');
    assert(size != null);
    assert(!size.isEmpty);

    final Map<Object?, Object?>? meta =
        await SystemChannels.platform_views.invokeMapMethod<Object?, Object?>(
      'resize',
      <String, dynamic>{
        'id': viewId,
        'width': size.width,
        'height': size.height,
      },
    );
    assert(meta != null);
    assert(meta!.containsKey('width'));
    assert(meta!.containsKey('height'));
    return Size(meta!['width']! as double, meta['height']! as double);
  }

  @override
  Future<void> setOffset(Offset off) async {
    if (off == _off) {
      return;
    }

    if (_state != _TizenViewState.created) {
      return;
    }

    _off = off;

    await SystemChannels.platform_views.invokeMethod<void>(
      'offset',
      <String, dynamic>{
        'id': viewId,
        'top': off.dy,
        'left': off.dx,
      },
    );
  }

  @override
  bool get _createRequiresSize => true;

  @override
  Future<void> _sendCreateMessage({required Size size}) async {
    assert(!size.isEmpty,
        'trying to create $TextureTizenViewController without setting a valid size.');

    final Map<String, dynamic> args = <String, dynamic>{
      'id': viewId,
      'viewType': _viewType,
      'width': size.width,
      'height': size.height,
      'direction': _layoutDirection == TextDirection.ltr ? 0 : 1,
    };
    if (_creationParams != null) {
      final ByteData paramsByteData =
          _creationParamsCodec!.encodeMessage(_creationParams)!;
      args['params'] = Uint8List.view(
        paramsByteData.buffer,
        0,
        paramsByteData.lengthInBytes,
      );
    }
    _textureId =
        await SystemChannels.platform_views.invokeMethod<int>('create', args);
  }

  @override
  Future<void> _sendDisposeMessage() {
    return SystemChannels.platform_views
        .invokeMethod<void>('dispose', <String, dynamic>{
      'id': viewId,
      'hybrid': false,
    });
  }

  bool get isCreated => _state == _TizenViewState.created;
}

/// Provides access to the platform views service on Tizen.
///
/// Source: [PlatformViewsService] in flutter/src/services/platform_views.dart
class PlatformViewsServiceTizen {
  PlatformViewsServiceTizen._() {
    SystemChannels.platform_views.setMethodCallHandler(_onMethodCall);
  }
  static final PlatformViewsServiceTizen _instance =
      PlatformViewsServiceTizen._();

  Future<void> _onMethodCall(MethodCall call) {
    switch (call.method) {
      case 'viewFocused':
        final int id = call.arguments as int;
        if (_focusCallbacks.containsKey(id)) {
          _focusCallbacks[id]!();
        }
        break;
      default:
        throw UnimplementedError(
            "${call.method} was invoked but isn't implemented by PlatformViewsService");
    }
    return Future<void>.value();
  }

  final Map<int, VoidCallback> _focusCallbacks = <int, VoidCallback>{};

  static TextureTizenViewController initTizenView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    assert(id != null);
    assert(viewType != null);
    assert(layoutDirection != null);
    assert(creationParams == null || creationParamsCodec != null);

    final TextureTizenViewController controller = TextureTizenViewController._(
      viewId: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
    );

    _instance._focusCallbacks[id] = onFocus ?? () {};
    return controller;
  }
}

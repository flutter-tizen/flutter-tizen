// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../rendering/platform_view.dart';
import '../services/platform_views.dart';

/// Embeds an Tizen view in the Widget hierarchy.
//
/// Source: [AndroidView] in flutter/lib/src/widgets/platform_view.dart
class TizenView extends StatefulWidget {
  const TizenView({
    super.key,
    required this.viewType,
    this.onPlatformViewCreated,
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    this.layoutDirection,
    this.gestureRecognizers,
    this.creationParams,
    this.creationParamsCodec,
    this.clipBehavior = Clip.hardEdge,
  })  : assert(viewType != null),
        assert(hitTestBehavior != null),
        assert(creationParams == null || creationParamsCodec != null);

  final String viewType;
  final PlatformViewCreatedCallback? onPlatformViewCreated;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final TextDirection? layoutDirection;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;
  final dynamic creationParams;
  final MessageCodec<dynamic>? creationParamsCodec;
  final Clip clipBehavior;

  @override
  State<TizenView> createState() => _TizenViewState();
}

/// A state object for an Tizen view.
///
/// Source: [_AndroidViewState] in flutter/lib/src/widgets/platform_view.dart
class _TizenViewState extends State<TizenView> {
  int? _id;
  late TextureTizenViewController _controller;
  TextDirection? _layoutDirection;
  bool _initialized = false;
  FocusNode? _focusNode;

  static final Set<Factory<OneSequenceGestureRecognizer>> _emptyRecognizersSet =
      <Factory<OneSequenceGestureRecognizer>>{};

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: _onFocusChange,
      child: _TizenPlatformView(
        controller: _controller,
        hitTestBehavior: widget.hitTestBehavior,
        gestureRecognizers: widget.gestureRecognizers ?? _emptyRecognizersSet,
        clipBehavior: widget.clipBehavior,
      ),
    );
  }

  void _initializeOnce() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _createNewTizenView();
    _focusNode = FocusNode(debugLabel: 'TizenView(id: $_id)');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection =
        _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    _initializeOnce();
    if (didChangeLayoutDirection) {
      _controller.setLayoutDirection(_layoutDirection!);
    }
  }

  @override
  void didUpdateWidget(TizenView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final TextDirection newLayoutDirection = _findLayoutDirection();
    final bool didChangeLayoutDirection =
        _layoutDirection != newLayoutDirection;
    _layoutDirection = newLayoutDirection;

    if (widget.viewType != oldWidget.viewType) {
      _controller.dispose();
      _createNewTizenView();
      return;
    }

    if (didChangeLayoutDirection) {
      _controller.setLayoutDirection(_layoutDirection!);
    }
  }

  TextDirection _findLayoutDirection() {
    assert(
        widget.layoutDirection != null || debugCheckHasDirectionality(context));
    return widget.layoutDirection ?? Directionality.of(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _createNewTizenView() {
    _id = platformViewsRegistry.getNextPlatformViewId();
    _controller = PlatformViewsServiceTizen.initTizenView(
      id: _id!,
      viewType: widget.viewType,
      layoutDirection: _layoutDirection!,
      creationParams: widget.creationParams,
      creationParamsCodec: widget.creationParamsCodec,
      onFocus: () {
        _focusNode!.requestFocus();
      },
    );
    if (widget.onPlatformViewCreated != null) {
      _controller
          .addOnPlatformViewCreatedListener(widget.onPlatformViewCreated!);
    }
  }

  void _onFocusChange(bool isFocused) {
    if (!_controller.isCreated) {
      return;
    }
    if (!isFocused) {
      _controller.clearFocus().catchError((dynamic e) {
        if (e is MissingPluginException) {
          return;
        }
      });
      return;
    }
    SystemChannels.textInput.invokeMethod<void>(
      'TextInput.setPlatformViewClient',
      <String, dynamic>{'platformViewId': _id},
    ).catchError((dynamic e) {
      if (e is MissingPluginException) {
        return;
      }
    });
  }
}

/// A render object widget for an Tizen view.
///
/// Source: [_AndroidPlatformView] in flutter/lib/src/widgets/platform_view.dart
class _TizenPlatformView extends LeafRenderObjectWidget {
  const _TizenPlatformView({
    required this.controller,
    required this.hitTestBehavior,
    required this.gestureRecognizers,
    this.clipBehavior = Clip.hardEdge,
  })  : assert(controller != null),
        assert(hitTestBehavior != null),
        assert(gestureRecognizers != null);

  final TextureTizenViewController controller;
  final PlatformViewHitTestBehavior hitTestBehavior;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderTizenView(
        viewController: controller,
        hitTestBehavior: hitTestBehavior,
        gestureRecognizers: gestureRecognizers,
        clipBehavior: clipBehavior,
      );

  @override
  void updateRenderObject(BuildContext context, RenderTizenView renderObject) {
    renderObject.controller = controller;
    renderObject.hitTestBehavior = hitTestBehavior;
    renderObject.updateGestureRecognizers(gestureRecognizers);
    renderObject.clipBehavior = clipBehavior;
  }
}

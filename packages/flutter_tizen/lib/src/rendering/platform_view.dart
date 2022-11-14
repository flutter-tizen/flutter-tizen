// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import '../services/platform_views.dart';

/// Source: [_PlatformViewState] flutter/packages/flutter/lib/src/rendering/platform_view.dart
enum _PlatformViewState {
  uninitialized,
  resizing,
  ready,
}

/// A render object for an Tizen view.
///
/// Source: [RenderAndroidView] flutter/packages/flutter/lib/src/rendering/platform_view.dart
class RenderTizenView extends PlatformViewRenderBox {
  RenderTizenView({
    required TextureTizenViewController viewController,
    required PlatformViewHitTestBehavior hitTestBehavior,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
    Clip clipBehavior = Clip.hardEdge,
  })  : assert(viewController != null),
        assert(hitTestBehavior != null),
        assert(gestureRecognizers != null),
        assert(clipBehavior != null),
        _viewController = viewController,
        _clipBehavior = clipBehavior,
        super(
            controller: viewController,
            hitTestBehavior: hitTestBehavior,
            gestureRecognizers: gestureRecognizers) {
    updateGestureRecognizers(gestureRecognizers);
    _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
    this.hitTestBehavior = hitTestBehavior;
  }

  _PlatformViewState _state = _PlatformViewState.uninitialized;

  Size? _currentTextureSize;

  @override
  TextureTizenViewController get controller => _viewController;

  TextureTizenViewController _viewController;

  @override
  set controller(TextureTizenViewController viewController) {
    assert(_viewController != null);
    assert(viewController != null);
    if (_viewController == viewController) {
      return;
    }
    _viewController.removeOnPlatformViewCreatedListener(_onPlatformViewCreated);
    _viewController = viewController;
    _sizePlatformView();
    if (_viewController.isCreated) {
      markNeedsSemanticsUpdate();
    }
    _viewController.addOnPlatformViewCreatedListener(_onPlatformViewCreated);
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.hardEdge;
  set clipBehavior(Clip value) {
    assert(value != null);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  void _onPlatformViewCreated(int id) {
    markNeedsSemanticsUpdate();
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performResize() {
    super.performResize();
    _sizePlatformView();
  }

  Future<void> _sizePlatformView() async {
    if (_state == _PlatformViewState.resizing || size.isEmpty) {
      return;
    }

    _state = _PlatformViewState.resizing;
    markNeedsPaint();

    Size targetSize;
    do {
      targetSize = size;
      if (_viewController.isCreated) {
        _currentTextureSize = await _viewController.setSize(targetSize);
      } else {
        await _viewController.create(size: targetSize);
        _currentTextureSize = targetSize;
      }
    } while (size != targetSize);

    _state = _PlatformViewState.ready;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_viewController.textureId == null || _currentTextureSize == null)
      return;

    final bool isTextureLargerThanWidget =
        _currentTextureSize!.width > size.width ||
            _currentTextureSize!.height > size.height;
    if (isTextureLargerThanWidget && clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        true,
        offset,
        offset & size,
        _paintTexture,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
      return;
    }
    _clipRectLayer.layer = null;
    _paintTexture(context, offset);
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  void _paintTexture(PaintingContext context, Offset offset) {
    if (_currentTextureSize == null) {
      return;
    }

    context.addLayer(TextureLayer(
      rect: offset & _currentTextureSize!,
      textureId: _viewController.textureId!,
    ));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config.isSemanticBoundary = true;

    if (_viewController.isCreated) {
      config.platformViewId = _viewController.viewId;
    }
  }
}

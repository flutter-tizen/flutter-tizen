// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using NSubstitute;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class FlutterPluginRegistrarTests
    {
        [Fact]
        public void Ensure_Attached_When_Register_Plugin()
        {
            var registry = Substitute.For<IPluginRegistry>();
            var registrar = registry.GetRegistrarForDotnetPlugin();
            var plugin = Substitute.For<IFlutterPlugin>();

            registrar.RegisterPlugin(plugin);

            plugin.Received().OnAttachedToEngine(Arg.Any<IFlutterPluginBinding>());
        }
    }
}

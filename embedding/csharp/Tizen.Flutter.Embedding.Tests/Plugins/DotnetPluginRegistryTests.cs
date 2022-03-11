// Copyright 2022 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using NSubstitute;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class DotnetPluginRegistryTests
    {
        public class TheAddPluginMethod
        {
            [Fact]
            public void Ensures_Plugin_Is_Not_Null()
            {
                Assert.Throws<ArgumentNullException>(() =>
                    DotnetPluginRegistry.Instance.AddPlugin(null)
                );
            }

            [Fact]
            public void Adds_Plugin_Correctly()
            {
                var plugin = Substitute.For<IFlutterPlugin>();
                DotnetPluginRegistry.Instance.AddPlugin(plugin);
                Assert.True(DotnetPluginRegistry.Instance.HasPlugin(plugin));
            }

            [Fact]
            public void Ensures_Attached_When_Register_Plugin()
            {
                var plugin = Substitute.For<IFlutterPlugin>();
                DotnetPluginRegistry.Instance.AddPlugin(plugin);
                plugin.Received().OnAttachedToEngine(Arg.Any<IFlutterPluginBinding>());
            }
        }

        public class TheRemovePluginMethod
        {
            [Fact]
            public void Ensures_Plugin_Is_Not_Null()
            {
                Assert.Throws<ArgumentNullException>(() =>
                    DotnetPluginRegistry.Instance.RemovePlugin(null)
                );
            }

            [Fact]
            public void Removes_Plugin_Correctly()
            {
                var plugin = Substitute.For<IFlutterPlugin>();
                DotnetPluginRegistry.Instance.AddPlugin(plugin);
                Assert.True(DotnetPluginRegistry.Instance.HasPlugin(plugin));
                DotnetPluginRegistry.Instance.RemovePlugin(plugin);
                Assert.False(DotnetPluginRegistry.Instance.HasPlugin(plugin));
            }

            [Fact]
            public void Ensures_Detached_When_Unregister_Plugin()
            {
                var plugin = Substitute.For<IFlutterPlugin>();
                DotnetPluginRegistry.Instance.AddPlugin(plugin);
                DotnetPluginRegistry.Instance.RemovePlugin(plugin);
                plugin.Received().OnDetachedFromEngine();
            }
        }
    }
}

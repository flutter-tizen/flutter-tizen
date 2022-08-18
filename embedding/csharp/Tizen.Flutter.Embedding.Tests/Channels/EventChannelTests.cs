// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using NSubstitute;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class EventChannelTests
    {
        const string TEST_CHANNEL_NAME = "TEST/CHANNEL";

        public class TheCtor
        {
            [Fact]
            public void Ensures_Name_Is_Not_Null_Or_Empty()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                Assert.Throws<ArgumentException>(() => new EventChannel("", StandardMethodCodec.Instance, messenger));
                Assert.Throws<ArgumentException>(() => new EventChannel(null, StandardMethodCodec.Instance, messenger));
            }

            [Fact]
            public void Ensures_Codec_Is_Not_Null()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                Assert.Throws<ArgumentNullException>(() => new EventChannel(TEST_CHANNEL_NAME, null, messenger));
            }

            [Fact]
            public void Ensures_Messenger_Is_Not_Null()
            {
                Assert.Throws<ArgumentNullException>(() => new EventChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, null));
            }
        }

        public class TheSetStreamHandlerMethod
        {
            [Fact]
            public void Registers_Stream_Handler()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var handler = Substitute.For<IEventStreamHandler>();
                var channel = new EventChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);
                channel.SetStreamHandler(handler);

                messenger.Received().SetMessageHandler(Arg.Is<string>(x => x == TEST_CHANNEL_NAME),
                                                       Arg.Any<BinaryMessageHandler>());
            }

            [Fact]
            public void Ensures_StreamHandler_Callbacks()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var handler = Substitute.For<IEventStreamHandler>();
                var channel = new EventChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);
                byte[] listenCall = StandardMethodCodec.Instance.EncodeMethodCall(new MethodCall("listen", 1));
                byte[] cancelCall = StandardMethodCodec.Instance.EncodeMethodCall(new MethodCall("cancel", 1));
                messenger.When(x => x.SetMessageHandler(TEST_CHANNEL_NAME, Arg.Any<BinaryMessageHandler>()))
                         .Do(x =>
                         {
                             var binaryHandler = x[1] as BinaryMessageHandler;
                             binaryHandler(listenCall);
                             binaryHandler(cancelCall);
                         });

                channel.SetStreamHandler(handler);

                handler.Received().OnListen(Arg.Is<int>(x => x == 1), Arg.Any<IEventSink>());
                handler.Received().OnCancel(Arg.Is<int>(x => x == 1));
            }

            [Fact]
            public void Unregisters_Message_Handler()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new EventChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);
                channel.SetStreamHandler(null);

                messenger.Received().SetMessageHandler(Arg.Is<string>(x => x == TEST_CHANNEL_NAME), null);
            }
        }
    }
}

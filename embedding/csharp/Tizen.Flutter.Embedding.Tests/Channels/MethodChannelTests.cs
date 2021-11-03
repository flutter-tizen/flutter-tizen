// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Linq;
using NSubstitute;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class MethodChannelTests
    {
        private const string TEST_CHANNEL_NAME = "TEST_METHOD_CHANNEL";
        private const string TEST_METHOD_NAME = "TEST_METHOD_NAME";

        public class TheCtor
        {
            [Fact]
            public void Ensures_Name_Is_Not_Null_Or_Empty()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                Assert.Throws<ArgumentException>(() => new MethodChannel("", StandardMethodCodec.Instance, messenger));
                Assert.Throws<ArgumentException>(() => new MethodChannel(null, StandardMethodCodec.Instance, messenger));
            }

            [Fact]
            public void Ensures_Codec_Is_Not_Null()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                Assert.Throws<ArgumentNullException>(() => new MethodChannel(TEST_CHANNEL_NAME, null, messenger));
            }

            [Fact]
            public void Ensures_Messenger_Is_Not_Null()
            {
                Assert.Throws<ArgumentNullException>(() => new MethodChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, null));
            }
        }

        public class TheInvokeMethod
        {
            [Fact]
            public void Requests_Correct_MethodCall()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var codec = StandardMethodCodec.Instance;
                var channel = new MethodChannel(TEST_CHANNEL_NAME, codec, messenger);
                var call = new MethodCall(TEST_METHOD_NAME, new int[] { 1, 2, 5 });
                channel.InvokeMethod(call.Method, call.Arguments);

                messenger.Received().Send(Arg.Is<string>(x => x == TEST_CHANNEL_NAME),
                                          Arg.Is<byte[]>(x => x.SequenceEqual(codec.EncodeMethodCall(call))));
            }

            [Fact]
            public void Requests_Null_Method_Name()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new MethodChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);

                Assert.Throws<ArgumentNullException>(() => channel.InvokeMethod(null, null));
            }

            [Fact]
            public void Requests_Null_Method_Call()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new MethodChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);

                Assert.Throws<ArgumentNullException>(() => channel.InvokeMethod(null));
            }
        }

        public class TheInvokeAsyncMethod
        {
            [Fact]
            public async void Requests_Correct_MethodCall_And_Returns_Success_Envelope()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var codec = StandardMethodCodec.Instance;
                var channel = new MethodChannel(TEST_CHANNEL_NAME, codec, messenger);
                var call = new MethodCall(TEST_METHOD_NAME, new int[] { 1, 2, 5 });
                byte[] encodedCall = codec.EncodeMethodCall(call);
                messenger.SendAsync(TEST_CHANNEL_NAME, Arg.Any<byte[]>())
                         .Returns(codec.EncodeSuccessEnvelope("TEST_RESULT"));

                var result = await channel.InvokeMethodAsync(call.Method, call.Arguments) as string;
                await messenger.Received().SendAsync(Arg.Is<string>(x => x == TEST_CHANNEL_NAME),
                                                     Arg.Is<byte[]>(x => x.SequenceEqual(encodedCall)));
                Assert.Equal("TEST_RESULT", result);
            }

            [Fact]
            public async void Requests_Correct_MethodCall_And_Returns_Error_Envelope()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var codec = StandardMethodCodec.Instance;
                var channel = new MethodChannel(TEST_CHANNEL_NAME, codec, messenger);
                var call = new MethodCall(TEST_METHOD_NAME, new int[] { 1, 2, 5 });
                byte[] encodedCall = codec.EncodeMethodCall(call);
                messenger.SendAsync(TEST_CHANNEL_NAME, Arg.Any<byte[]>())
                         .Returns(codec.EncodeErrorEnvelope("E0001", "TEST_ERROR", "TEST_ERROR_DETAILS"));

                var ex = await Assert.ThrowsAsync<FlutterException>(() =>
                  {
                      return channel.InvokeMethodAsync(call.Method, call.Arguments);
                  });
                Assert.Equal("E0001", ex.Code);
                Assert.Equal("TEST_ERROR", ex.Message);
                Assert.Equal("TEST_ERROR_DETAILS", ex.Details as string);
            }

            [Fact]
            public void Requests_Null_Method_Name()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new MethodChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);

                Assert.ThrowsAsync<ArgumentNullException>(() => channel.InvokeMethodAsync(null, null));
            }

            [Fact]
            public void Requests_Null_Method_Call()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new MethodChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);

                Assert.ThrowsAsync<ArgumentNullException>(() => channel.InvokeMethodAsync(null));
            }
        }

        public class TheSetMethodCallHandlerMethod
        {
            [Fact]
            public void Registers_Message_Handler()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new MethodChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);
                channel.SetMethodCallHandler((call) =>
                {
                    return null;
                });

                messenger.Received().SetMessageHandler(Arg.Is<string>(x => x == TEST_CHANNEL_NAME),
                                                       Arg.Any<BinaryMessageHandler>());
            }

            [Fact]
            public void Unregisters_Message_Handler()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new MethodChannel(TEST_CHANNEL_NAME, StandardMethodCodec.Instance, messenger);
                channel.SetMethodCallHandler(null);

                messenger.Received().SetMessageHandler(Arg.Is<string>(x => x == TEST_CHANNEL_NAME), null);
            }
        }
    }
}

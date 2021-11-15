// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Linq;
using System.Threading.Tasks;
using NSubstitute;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class BasicMessageChannelTests
    {
        const string TEST_CHANNEL_NAME = "TEST/CHANNEL";

        public class TheCtor
        {
            [Fact]
            public void Ensures_Name_Is_Not_Null_Or_Empty()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                Assert.Throws<ArgumentException>(() => new BasicMessageChannel<string>("", new StringCodec(), messenger));
                Assert.Throws<ArgumentException>(() => new BasicMessageChannel<string>(null, new StringCodec(), messenger));
            }

            [Fact]
            public void Ensures_Codec_Is_Not_Null()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                Assert.Throws<ArgumentNullException>(() => new BasicMessageChannel<string>(TEST_CHANNEL_NAME, null, messenger));
            }

            [Fact]
            public void Ensures_Messenger_Is_Not_Null()
            {
                Assert.Throws<ArgumentNullException>(() => new BasicMessageChannel<string>(TEST_CHANNEL_NAME, new StringCodec(), null));
            }
        }

        public class TheSendMethod
        {
            [Fact]
            public void Requests_Correct_Message()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new BasicMessageChannel<string>(TEST_CHANNEL_NAME, new StringCodec(), messenger);
                channel.Send(StringCodecTests.TEST_STRING);

                messenger.Received().Send(Arg.Is<string>(x => x == TEST_CHANNEL_NAME),
                                          Arg.Is<byte[]>(x => x.SequenceEqual(StringCodecTests.TEST_BYTES)));
            }

            [Fact]
            public void Requests_Null_Message()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new BasicMessageChannel<string>(TEST_CHANNEL_NAME, new StringCodec(), messenger);
                channel.Send(null);

                messenger.Received().Send(Arg.Is<string>(x => x == TEST_CHANNEL_NAME), null);
            }
        }

        public class TheSendAsyncMethod
        {
            [Fact]
            public async Task Requests_Correct_Message()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new BasicMessageChannel<string>(TEST_CHANNEL_NAME, new StringCodec(), messenger);
                await channel.SendAsync(StringCodecTests.TEST_STRING);

                await messenger.Received().SendAsync(Arg.Is<string>(x => x == TEST_CHANNEL_NAME),
                                                     Arg.Is<byte[]>(x => x.SequenceEqual(StringCodecTests.TEST_BYTES)));
            }

            [Fact]
            public async Task Requests_Null_Message()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new BasicMessageChannel<string>(TEST_CHANNEL_NAME, new StringCodec(), messenger);
                await channel.SendAsync(null);

                await messenger.Received().SendAsync(Arg.Is<string>(x => x == TEST_CHANNEL_NAME), null);
            }
        }

        public class TheSetMessageHandlerMethod
        {
            [Fact]
            public void Registers_Message_Handler()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new BasicMessageChannel<string>(TEST_CHANNEL_NAME, new StringCodec(), messenger);
                channel.SetMessageHandler((message) =>
                {
                    return null;
                });

                messenger.Received().SetMessageHandler(Arg.Is<string>(x => x == TEST_CHANNEL_NAME), Arg.Any<BinaryMessageHandler>());
            }

            [Fact]
            public void Unregisters_Message_Handler()
            {
                var messenger = Substitute.For<IBinaryMessenger>();
                var channel = new BasicMessageChannel<string>(TEST_CHANNEL_NAME, new StringCodec(), messenger);
                channel.SetMessageHandler(null);

                messenger.Received().SetMessageHandler(Arg.Is<string>(x => x == TEST_CHANNEL_NAME), null);
            }
        }
    }
}

// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class BinaryCodecTests
    {
        [Fact]
        public void Can_Encode()
        {
            byte[] message = { 1, 2, 3, 4, 5 };
            BinaryCodec codec = new BinaryCodec();
            var ret = codec.EncodeMessage(message);

            Assert.Equal(message, ret);
        }

        [Fact]
        public void Can_Decode()
        {
            byte[] message = { 1, 2, 3, 4, 5 };
            BinaryCodec codec = new BinaryCodec();
            var ret = codec.DecodeMessage(message);

            Assert.Equal(message, ret);
        }

        [Fact]
        public void Returns_Null_If_Message_Is_Null() {
            BinaryCodec codec = new BinaryCodec();
            Assert.Null(codec.EncodeMessage(null));
            Assert.Null(codec.DecodeMessage(null));
        }
    }
}

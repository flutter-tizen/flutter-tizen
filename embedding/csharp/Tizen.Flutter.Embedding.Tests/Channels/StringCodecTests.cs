// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class StringCodecTests
    {
        public static readonly string TEST_STRING = "안녕하세요. 你好。Hello. おはようございます";
        public static readonly byte[] TEST_BYTES =
            { 236, 149, 136, 235, 133, 149, 237, 149, 152, 236, 132, 184, 236, 154, 148,
               46,  32, 228, 189, 160, 229, 165, 189, 227, 128, 130,  72, 101, 108, 108,
              111,  46,  32, 227, 129, 138, 227, 129, 175, 227, 130, 136, 227, 129, 134,
              227, 129, 148, 227, 129, 150, 227, 129, 132, 227, 129, 190, 227, 129, 153 };

        [Fact]
        public void Can_Encode()
        {
            var codec = new StringCodec();
            var ret = codec.EncodeMessage(TEST_STRING);

            Assert.Equal(TEST_BYTES, ret);
        }

        [Fact]
        public void Can_Decode()
        {
            var codec = new StringCodec();
            var ret = codec.DecodeMessage(TEST_BYTES);

            Assert.Equal(TEST_STRING, ret);
        }

        [Fact]
        public void Returns_Null_If_Message_Is_Null()
        {
            var codec = new StringCodec();
            Assert.Null(codec.EncodeMessage(null));
            Assert.Null(codec.DecodeMessage(null));
        }
    }
}

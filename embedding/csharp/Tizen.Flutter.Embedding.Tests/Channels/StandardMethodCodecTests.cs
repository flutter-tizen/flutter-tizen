// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.IO;
using System.Collections;
using Xunit;
using static Tizen.Flutter.Embedding.StandardMessageHelper;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class StandardMethodCodecTests
    {
        [Fact]
        public void Encodes_Correct_MethodCall()
        {
            var codec = StandardMethodCodec.Instance;
            var methodCall = new MethodCall("TestMethod", new ArrayList() { 1, "TestArg", true });
            byte[] result = codec.EncodeMethodCall(methodCall);
            byte[] expected;
            using (var stream = new MemoryStream())
            {
                stream.WriteByte(7); // STRING
                WriteUTF8String(stream, "TestMethod");
                stream.WriteByte(12); // LIST
                WriteSize(stream, 3);
                stream.WriteByte(3); // INT
                stream.Write(BitConverter.GetBytes(1));
                stream.WriteByte(7); // STRING
                WriteUTF8String(stream, "TestArg");
                stream.WriteByte(1); // TRUE
                expected = stream.ToArray();
            }

            Assert.Equal(expected, result);
        }

        [Fact]
        public void Encodes_Correct_SuccessEnvelope()
        {
            var codec = StandardMethodCodec.Instance;
            var encoded = codec.EncodeSuccessEnvelope("TestObject");
            byte[] expected;
            using (var stream = new MemoryStream())
            {
                stream.WriteByte(0); // SUCCESS
                stream.WriteByte(7); // STRING
                WriteUTF8String(stream, "TestObject");
                expected = stream.ToArray();
            }
            Assert.Equal(expected, encoded);
        }

        [Fact]
        public void Encodes_Correct_ErrorEnvelope()
        {
            var codec = StandardMethodCodec.Instance;
            var encoded = codec.EncodeErrorEnvelope("E0001", "TestError", new ArrayList() { 1, "TestData", false });
            byte[] expected;
            using (var stream = new MemoryStream())
            {
                stream.WriteByte(1); // ERROR
                stream.WriteByte(7); // STRING
                WriteUTF8String(stream, "E0001");
                stream.WriteByte(7); // STRING
                WriteUTF8String(stream, "TestError");
                stream.WriteByte(12); // LIST
                WriteSize(stream, 3);
                stream.WriteByte(3); // INT
                stream.Write(BitConverter.GetBytes(1));
                stream.WriteByte(7); // STRING
                WriteUTF8String(stream, "TestData");
                stream.WriteByte(2); // FALSE
                expected = stream.ToArray();
            }
            Assert.Equal(expected, encoded);
        }

        [Fact]
        public void Decodes_Correct_MethodCall()
        {
            var codec = StandardMethodCodec.Instance;
            var methodCall = new MethodCall("TestMethod", new ArrayList() { 1, "TestArg", true });
            byte[] encoded = codec.EncodeMethodCall(methodCall);
            MethodCall decoded = codec.DecodeMethodCall(encoded);

            Assert.Equal("TestMethod", decoded.Method);
            Assert.IsType<ArrayList>(decoded.Arguments);
            var arguments = decoded.Arguments as ArrayList;
            Assert.Equal(3, arguments.Count);
            Assert.Equal(1, arguments[0]);
            Assert.Equal("TestArg", arguments[1]);
            Assert.Equal(true, arguments[2]);
        }

        [Fact]
        public void Decodes_Correct_Success_Envelope()
        {
            var codec = StandardMethodCodec.Instance;
            byte[] encoded = codec.EncodeSuccessEnvelope("SUCCESS_ENVELOPE");
            string decoded = codec.DecodeEnvelope(encoded) as string;
            Assert.Equal("SUCCESS_ENVELOPE", decoded);
        }

        [Fact]
        public void Decodes_Correct_Error_Envelope()
        {
            var codec = StandardMethodCodec.Instance;
            byte[] encoded = codec.EncodeErrorEnvelope("E0001", "TEST_MESSAGE", "TEST_DETAILS");
            var exception = Assert.Throws<FlutterException>(() =>
            {
                codec.DecodeEnvelope(encoded);
            });
            Assert.Equal("E0001", exception.Code);
            Assert.Equal("TEST_MESSAGE", exception.Message);
            Assert.Equal("TEST_DETAILS", exception.Details);
        }

        [Fact]
        public void Throws_When_Message_Is_Corrupted()
        {
            var codec = StandardMethodCodec.Instance;
            var encoded = codec.EncodeMethodCall(new MethodCall("TEST_METHOD", 1));
            using (var corrupted = new MemoryStream(encoded))
            {
                corrupted.WriteByte(127);
                Assert.Throws<InvalidOperationException>(() =>
                {
                    codec.DecodeMethodCall(corrupted.ToArray());
                });
            }
        }
    }
}

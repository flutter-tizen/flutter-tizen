// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using System.Text;
using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class StandardMessageCodecTests
    {
        private const byte NULL = 0;
        private const byte TRUE = 1;
        private const byte FALSE = 2;
        private const byte INT = 3;
        private const byte LONG = 4;
        private const byte BIGINT = 5;
        private const byte DOUBLE = 6;
        private const byte STRING = 7;
        private const byte BYTE_ARRAY = 8;
        private const byte INT_ARRAY = 9;
        private const byte LONG_ARRAY = 10;
        private const byte DOUBLE_ARRAY = 11;
        private const byte LIST = 12;
        private const byte MAP = 13;
        private const byte FLOAT_ARRAY = 14;

        public class TheEncodeMethod
        {
            [Fact]
            public void Encodes_Correct_Null_Literals()
            {
                var codec = new StandardMessageCodec();
                var content = new List<object> { null };
                var encodedValue = codec.EncodeMessage(content);
                Assert.Equal(new byte[] { LIST, 1, NULL }, encodedValue);
            }

            [Fact]
            public void Encodes_Correct_Booleans()
            {
                var codec = new StandardMessageCodec();
                var content = new List<object> { true, false };
                var encodedValue = codec.EncodeMessage(content);
                Assert.Equal(new byte[] { LIST, 2, TRUE, FALSE }, encodedValue);
            }

            [Fact]
            public void Encodes_Correct_IntegerList()
            {
                var codec = new StandardMessageCodec();
                var content = new List<object> { (short)1, 2U, 5 };
                var encodedValue = codec.EncodeMessage(content);

                byte[] expected;
                using (var stream = new MemoryStream())
                {
                    stream.WriteByte(LIST);
                    stream.WriteByte(3);
                    stream.WriteByte(INT);
                    stream.Write(BitConverter.GetBytes(1));
                    stream.WriteByte(INT);
                    stream.Write(BitConverter.GetBytes(2));
                    stream.WriteByte(INT);
                    stream.Write(BitConverter.GetBytes(5));
                    expected = stream.ToArray();
                }
                Assert.Equal(expected, encodedValue);
            }

            [Fact]
            public void Encodes_Correct_LongList()
            {
                var codec = new StandardMessageCodec();
                var content = new List<object> { 1L, 2L, 5L };
                var encodedValue = codec.EncodeMessage(content);

                byte[] expected;
                using (var stream = new MemoryStream())
                {
                    stream.WriteByte(LIST);
                    stream.WriteByte(3);
                    stream.WriteByte(LONG);
                    stream.Write(BitConverter.GetBytes(1L));
                    stream.WriteByte(LONG);
                    stream.Write(BitConverter.GetBytes(2L));
                    stream.WriteByte(LONG);
                    stream.Write(BitConverter.GetBytes(5L));
                    expected = stream.ToArray();
                }
                Assert.Equal(expected, encodedValue);
            }

            [Fact]
            public void Encodes_Correct_FloatList()
            {
                var codec = new StandardMessageCodec();
                var content = new List<object> { 1.1d, 2.2f, 5.5d };
                var encodedValue = codec.EncodeMessage(content);

                byte[] expected;
                using (var stream = new MemoryStream())
                {
                    stream.WriteByte(LIST);
                    stream.WriteByte(3);
                    stream.WriteByte(DOUBLE);
                    CodecTestsHelper.WriteAlignment(stream, 8);
                    stream.Write(BitConverter.GetBytes(1.1d));
                    stream.WriteByte(DOUBLE);
                    CodecTestsHelper.WriteAlignment(stream, 8);
                    stream.Write(BitConverter.GetBytes(Convert.ToDouble(2.2f)));
                    stream.WriteByte(DOUBLE);
                    CodecTestsHelper.WriteAlignment(stream, 8);
                    stream.Write(BitConverter.GetBytes(5.5d));
                    expected = stream.ToArray();
                }
                Assert.Equal(expected, encodedValue);
            }

            [Theory]
            [InlineData("123456789012345678901234567890", "18ee90ff6c373e0ee4e3f0ad2")]
            [InlineData("999999999999999999999999999999", "0c9f2c9cd04674edea3fffffff")]
            public void Encodes_Correct_BigInteger(string value, string hex)
            {
                var codec = new StandardMessageCodec();
                var encoded = codec.EncodeMessage(BigInteger.Parse(value));
                byte[] expected;
                using (var stream = new MemoryStream())
                {
                    stream.WriteByte(BIGINT);
                    CodecTestsHelper.WriteBytes(stream, Encoding.UTF8.GetBytes(hex));
                    expected = stream.ToArray();
                }
                Assert.Equal(expected, encoded);
            }

            [Theory]
            [InlineData("TEST_STRING")]
            [InlineData("HELLO Flutter!")]
            public void Encodes_Correct_ByteArray(string value)
            {
                var codec = new StandardMessageCodec();
                var bytes = Encoding.UTF8.GetBytes(value);
                var encoded = codec.EncodeMessage(bytes);
                byte[] expected;
                using (var stream = new MemoryStream())
                {
                    stream.WriteByte(BYTE_ARRAY);
                    CodecTestsHelper.WriteBytes(stream, bytes);
                    expected = stream.ToArray();
                }
                Assert.Equal(expected, encoded);
            }

            [Theory]
            [InlineData(new int[] { 1, 2, 5 }, INT_ARRAY, 4)]
            [InlineData(new long[] { 1L, 2L, 5L }, LONG_ARRAY, 8)]
            [InlineData(new float[] { 1.1f, 2.2f, 5.5f }, FLOAT_ARRAY, 4)]
            [InlineData(new double[] { 1.1d, 2.2d, 5.5d }, DOUBLE_ARRAY, 8)]
            public void Encodes_Correct_ArrayTypes(ICollection content, byte type, int alignment)
            {
                var codec = new StandardMessageCodec();
                var encodedValue = codec.EncodeMessage(content);
                byte[] expected;
                using (var stream = new MemoryStream())
                {
                    stream.WriteByte(type);
                    CodecTestsHelper.WriteSize(stream, content.Count);
                    CodecTestsHelper.WriteAlignment(stream, alignment);
                    foreach (dynamic value in content)
                    {
                        stream.Write(BitConverter.GetBytes(value));
                    }
                    expected = stream.ToArray();
                }
                Assert.Equal(expected, encodedValue);
            }

            [Fact]
            public void Encodes_Correct_String()
            {
                var codec = new StandardMessageCodec();
                var content = StringCodecTests.TEST_STRING;
                var encodedValue = codec.EncodeMessage(content);
                byte[] expected;
                using (var stream = new MemoryStream())
                {
                    stream.WriteByte(STRING);
                    CodecTestsHelper.WriteBytes(stream, StringCodecTests.TEST_BYTES);
                    expected = stream.ToArray();
                }
                Assert.Equal(expected, encodedValue);
            }

            [Fact]
            public void Returns_Null_If_Message_Is_Null()
            {
                var codec = new StandardMessageCodec();
                Assert.Null(codec.EncodeMessage(null));
            }

            [Fact]
            public void Throws_When_Message_Is_Not_Supported_Type()
            {
                var codec = new StandardMessageCodec();
                Assert.Throws<ArgumentException>(() =>
                {
                    codec.EncodeMessage((char)1);
                });
            }
        }

        public class TheDecodeMethod
        {
            public static IEnumerable<object[]> TestListValues =>
                new List<object[]>
                {
                    new object[] { new ArrayList { (short)1, (byte)2, 3, 4L } },
                    new object[] { new ArrayList { 1.1f, 2.2d, 5.5f } },
                    new object[] { new ArrayList { "Test String", 10 } },
                };

            [Theory]
            [InlineData(null)]
            [InlineData(true)]
            [InlineData(false)]
            [InlineData(1)]
            [InlineData(5L)]
            [InlineData(5.5d)]
            [InlineData("Test String")]
            [InlineData(new int[] { 1, 2, 5 })]
            [InlineData(new long[] { 1L, 2L, 5L })]
            [InlineData(new float[] { 1.1f, 2.2f, 5.5f })]
            [InlineData(new double[] { 1.1d, 2.2d, 5.5d })]
            public void Decodes_Correct_Value(object value)
            {
                var codec = new StandardMessageCodec();
                var encoded = codec.EncodeMessage(value);
                var decoded = codec.DecodeMessage(encoded);

                Assert.Equal(value, decoded);
            }

            [Theory]
            [InlineData("123456789012345678901234567890")]
            [InlineData("999999999999999999999999999999")]
            public void Decodes_Correct_BigInteger(string value)
            {
                var codec = new StandardMessageCodec();
                var encoded = codec.EncodeMessage(BigInteger.Parse(value));
                var decoded = codec.DecodeMessage(encoded);
                Assert.Equal(value, decoded.ToString());
            }

            [Theory]
            [MemberData(nameof(TestListValues))]
            public void Decodes_Correct_List(IList values)
            {
                var codec = new StandardMessageCodec();
                var encoded = codec.EncodeMessage(values);
                var decoded = codec.DecodeMessage(encoded) as IList;

                for (int i = 0; i < values.Count; i++)
                {
                    var value = values[i];
                    if (value is SByte || value is Int16 || value is Int32 ||
                        value is Byte || value is UInt16 || value is UInt32)
                    {
                        Assert.Equal(Convert.ToInt32(value), decoded[i]);
                    }
                    else if (value is Single || value is Double)
                    {
                        Assert.Equal(Convert.ToDouble(value), decoded[i]);
                    }
                    else
                    {
                        Assert.Equal(value, decoded[i]);
                    }
                }
            }

            [Fact]
            public void Returns_Null_If_Message_Is_Null()
            {
                var codec = new StandardMessageCodec();
                Assert.Null(codec.DecodeMessage(null));
            }

            [Fact]
            public void Throws_When_Message_Is_Corrupted()
            {
                var codec = new StandardMessageCodec();
                var encoded = codec.EncodeMessage("TEST_MESSAGE");
                var corrupted = new byte[encoded.Length + 1];
                Assert.Throws<InvalidOperationException>(() =>
                {
                    codec.DecodeMessage(corrupted);
                });
            }
        }
    }
}

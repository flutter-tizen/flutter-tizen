// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text;
using Tizen.Flutter.Embedding.Common;

[assembly: InternalsVisibleTo("Tizen.Flutter.Embedding.Tests")]

namespace Tizen.Flutter.Embedding
{
    internal static class StandardMessageHelper
    {
        public static void WriteAlignment(BinaryWriter writer, int alignment)
        {
            WriteAlignment(writer.BaseStream, alignment);
        }

        public static void WriteAlignment(Stream stream, int alignment)
        {
            long mod = stream.Length % alignment;
            if (mod != 0)
            {
                for (int i = 0; i < alignment - mod; i++)
                {
                    stream.WriteByte(0);
                }
            }
        }

        public static void ReadAlignment(BinaryReader reader, int alignment)
        {
            ReadAlignment(reader.BaseStream, alignment);
        }

        public static void ReadAlignment(Stream stream, int alignment)
        {
            long mod = stream.Position % alignment;
            if (mod != 0)
            {
                stream.Position = stream.Position + alignment - mod;
            }
        }

        public static void WriteSize(BinaryWriter writer, int size)
        {
            WriteSize(writer.BaseStream, size);
        }

        public static void WriteSize(Stream stream, int size)
        {
            if (size < 0)
            {
                throw new ArgumentException("value can not be negative.", nameof(size));
            }
            if (size < 254)
            {
                stream.WriteByte(Convert.ToByte(size));
            }
            else if (size <= 0xffff)
            {
                stream.WriteByte(254);
                WriteBytes(stream, BitConverter.GetBytes(Convert.ToUInt16(size)));
            }
            else
            {
                stream.WriteByte(255);
                WriteBytes(stream, BitConverter.GetBytes(Convert.ToInt32(size)));
            }
        }

        public static int ReadSize(BinaryReader reader)
        {
            if (!reader.BaseStream.HasRemaining())
            {
                throw new InvalidOperationException("Message corrupted");
            }
            int value = reader.ReadByte() & 0xff;
            if (value < 254)
            {
                return value;
            }
            else if (value == 254)
            {
                return reader.ReadInt16();
            }
            else
            {
                return reader.ReadInt32();
            }
        }

        public static void WriteBytes(Stream stream, byte[] bytes)
        {
            stream.Write(bytes, 0, bytes.Length);
        }

        public static void WriteBytesWithSize(Stream stream, byte[] bytes)
        {
            WriteSize(stream, bytes.Length);
            WriteBytes(stream, bytes);
        }

        public static void WriteUTF8String(Stream stream, string value)
        {
            WriteBytesWithSize(stream, Encoding.UTF8.GetBytes(value));
        }
    }
}

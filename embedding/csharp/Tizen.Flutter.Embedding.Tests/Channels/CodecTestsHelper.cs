// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.IO;
using System.Text;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public static class CodecTestsHelper
    {
        public static void WriteAlignment(MemoryStream buffer, int alignment)
        {
            long mod = buffer.Length % alignment;
            if (mod != 0)
            {
                for (int i = 0; i < alignment - mod; i++)
                {
                    buffer.WriteByte(0);
                }
            }
        }

        public static void WriteSize(MemoryStream buffer, int value)
        {
            if (value < 0)
            {
                throw new ArgumentException("value can not be negative.", nameof(value));
            }
            if (value < 254)
            {
                buffer.WriteByte(Convert.ToByte(value));
            }
            else if (value <= 0xffff)
            {
                buffer.WriteByte(254);
                var bytes = BitConverter.GetBytes(Convert.ToChar(value));
                buffer.Write(bytes, 0, bytes.Length);
            }
            else
            {
                buffer.WriteByte(255);
                var bytes = BitConverter.GetBytes(Convert.ToInt32(value));
                buffer.Write(bytes, 0, bytes.Length);
            }
        }

        public static void WriteBytes(MemoryStream buffer, byte[] bytes)
        {
            WriteSize(buffer, bytes.Length);
            buffer.Write(bytes);
        }

        public static void WriteString(MemoryStream buffer, string value)
        {
            WriteBytes(buffer, Encoding.UTF8.GetBytes(value));
        }
    }
}

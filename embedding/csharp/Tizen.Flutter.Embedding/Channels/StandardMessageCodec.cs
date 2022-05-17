// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections;
using System.Globalization;
using System.IO;
using System.Numerics;
using System.Text;
using Tizen.Flutter.Embedding.Common;
using static Tizen.Flutter.Embedding.StandardMessageHelper;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// <see cref="IMessageCodec{T}" /> using the Flutter standard binary encoding.
    /// <para>
    /// This codec is guaranteed to be compatible with the corresponding
    /// <see href = "https://api.flutter.dev/flutter/services/StandardMessageCodec-class.html">StandardMessageCodec</see>
    /// on the Dart side. These parts of the Flutter SDK are evolved synchronously.
    /// </para>
    /// </summary>
    public class StandardMessageCodec : IMessageCodec<object>
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

        /// <summary>
        /// Singleton instance of <see cref="StandardMessageCodec" />.
        /// </summary>
        public static StandardMessageCodec Instance => new StandardMessageCodec();

        private StandardMessageCodec()
        {
        }

        /// <InheritDoc/>
        public byte[] EncodeMessage(object message)
        {
            if (message == null)
            {
                return null;
            }
            using (var stream = new MemoryStream())
            using (var writer = new BinaryWriter(stream))
            {
                WriteValue(writer, message);
                return stream.ToArray();
            }
        }

        /// <InheritDoc/>
        public object DecodeMessage(byte[] message)
        {
            if (message == null)
            {
                return null;
            }

            using (var stream = new MemoryStream(message))
            using (var reader = new BinaryReader(stream))
            {
                var value = ReadValue(reader);
                if (stream.HasRemaining())
                {
                    throw new InvalidOperationException("Message corrupted");
                }
                return value;
            }
        }

        protected internal void WriteValue(BinaryWriter writer, object value)
        {
            if (value == null)
            {
                writer.Write(NULL);
            }
            else if (value is Boolean boolValue)
            {
                writer.Write(boolValue ? TRUE : FALSE);
            }
            else if (value is SByte || value is Int16 || value is Int32 ||
                     value is Byte || value is UInt16 || value is UInt32)
            {
                writer.Write(INT);
                writer.Write(Convert.ToInt32(value));
            }
            else if (value is Int64 || value is UInt64)
            {
                writer.Write(LONG);
                writer.Write(Convert.ToInt64(value));
            }
            else if (value is Single || value is Double)
            {
                writer.Write(DOUBLE);
                WriteAlignment(writer, 8);
                writer.Write(Convert.ToDouble(value));
            }
            else if (value is BigInteger bigValue)
            {
                writer.Write(BIGINT);
                var bytes = Encoding.UTF8.GetBytes(bigValue.ToString("x"));
                WriteSize(writer, bytes.Length);
                writer.Write(bytes);
            }
            else if (value is String strValue)
            {
                writer.Write(STRING);
                var bytes = Encoding.UTF8.GetBytes(strValue);
                WriteSize(writer, bytes.Length);
                writer.Write(bytes);
            }
            else if (value is byte[] bytesValue)
            {
                writer.Write(BYTE_ARRAY);
                WriteSize(writer, bytesValue.Length);
                writer.Write(bytesValue);
            }
            else if (value is int[] intArray)
            {
                writer.Write(INT_ARRAY);
                WriteSize(writer, intArray.Length);
                WriteAlignment(writer, 4);
                foreach (var n in intArray)
                {
                    writer.Write(n);
                }
            }
            else if (value is long[] longArray)
            {
                writer.Write(LONG_ARRAY);
                WriteSize(writer, longArray.Length);
                WriteAlignment(writer, 8);
                foreach (var n in longArray)
                {
                    writer.Write(n);
                }
            }
            else if (value is float[] floatArray)
            {
                writer.Write(FLOAT_ARRAY);
                WriteSize(writer, floatArray.Length);
                WriteAlignment(writer, 4);
                foreach (var n in floatArray)
                {
                    writer.Write(n);
                }
            }
            else if (value is double[] doubleArray)
            {
                writer.Write(DOUBLE_ARRAY);
                WriteSize(writer, doubleArray.Length);
                WriteAlignment(writer, 8);
                foreach (var n in doubleArray)
                {
                    writer.Write(n);
                }
            }
            else if (value is IDictionary mapValue)
            {
                writer.Write(MAP);
                WriteSize(writer, mapValue.Count);
                foreach (var k in mapValue.Keys)
                {
                    WriteValue(writer, k);
                    WriteValue(writer, mapValue[k]);
                }
            }
            else if (value is ICollection listValue)
            {
                writer.Write(LIST);
                WriteSize(writer, listValue.Count);
                foreach (var o in listValue)
                {
                    WriteValue(writer, o);
                }
            }
            else
            {
                throw new ArgumentException($"Unsupported value: '{value}' of type '{value.GetType().Name}'");
            }
        }

        protected internal object ReadValue(BinaryReader reader)
        {
            if (!reader.BaseStream.HasRemaining())
            {
                throw new InvalidOperationException("Message corrupted");
            }

            var type = reader.ReadByte();
            switch (type)
            {
                case NULL:
                    return null;
                case TRUE:
                    return true;
                case FALSE:
                    return false;
                case INT:
                    return reader.ReadInt32();
                case LONG:
                    return reader.ReadInt64();
                case DOUBLE:
                    ReadAlignment(reader, 8);
                    return reader.ReadDouble();
                case BIGINT:
                    {
                        var bytes = reader.ReadBytes(ReadSize(reader));
                        var hex = Encoding.UTF8.GetString(bytes);
                        return BigInteger.Parse(hex, NumberStyles.AllowHexSpecifier);
                    }
                case STRING:
                    {
                        var bytes = reader.ReadBytes(ReadSize(reader));
                        return Encoding.UTF8.GetString(bytes);
                    }
                case BYTE_ARRAY:
                    return reader.ReadBytes(ReadSize(reader));
                case INT_ARRAY:
                    {
                        var length = ReadSize(reader);
                        var array = new int[length];
                        ReadAlignment(reader, 4);
                        for (int i = 0; i < length; i++)
                        {
                            array[i] = reader.ReadInt32();
                        }
                        return array;
                    }
                case LONG_ARRAY:
                    {
                        var length = ReadSize(reader);
                        var array = new long[length];
                        ReadAlignment(reader, 8);
                        for (int i = 0; i < length; i++)
                        {
                            array[i] = reader.ReadInt64();
                        }
                        return array;
                    }
                case FLOAT_ARRAY:
                    {
                        var length = ReadSize(reader);
                        var array = new float[length];
                        ReadAlignment(reader, 4);
                        for (int i = 0; i < length; i++)
                        {
                            array[i] = reader.ReadSingle();
                        }
                        return array;
                    }
                case DOUBLE_ARRAY:
                    {
                        var length = ReadSize(reader);
                        var array = new double[length];
                        ReadAlignment(reader, 8);
                        for (int i = 0; i < length; i++)
                        {
                            array[i] = reader.ReadDouble();
                        }
                        return array;
                    }
                case LIST:
                    {
                        var size = ReadSize(reader);
                        var list = new ArrayList();
                        for (int i = 0; i < size; i++)
                        {
                            list.Add(ReadValue(reader));
                        }
                        return list;
                    }
                case MAP:
                    {
                        var size = ReadSize(reader);
                        var map = new Hashtable();
                        for (int i = 0; i < size; i++)
                        {
                            map.Add(ReadValue(reader), ReadValue(reader));
                        }
                        return map;
                    }
                default:
                    throw new InvalidOperationException("Message corrupted");
            }
        }
    }
}

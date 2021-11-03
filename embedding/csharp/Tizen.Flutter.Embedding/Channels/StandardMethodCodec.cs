// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.IO;
using Tizen.Flutter.Embedding.Common;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// <see cref="IMethodCodec" /> using the Flutter standard binary encoding.
    /// <para>
    /// This codec is guaranteed to be compatible with the corresponding
    /// <see href = "https://api.flutter.dev/flutter/services/StandardMethodCodec-class.html">StandardMethodCodec</see>
    /// on the Dart side. These parts of the Flutter SDK are evolved synchronously.
    /// </para>
    /// </summary>
    public class StandardMethodCodec : IMethodCodec
    {
        public StandardMethodCodec(StandardMessageCodec messageCodec)
        {
            MessageCodec = messageCodec;
        }

        public static StandardMethodCodec Instance => new StandardMethodCodec(StandardMessageCodec.Instance);


        public StandardMessageCodec MessageCodec { get; private set; }

        /// <InheritDoc/>
        public byte[] EncodeMethodCall(MethodCall methodCall)
        {
            using (var stream = new MemoryStream())
            using (var writer = new BinaryWriter(stream))
            {
                MessageCodec.WriteValue(writer, methodCall.Method);
                MessageCodec.WriteValue(writer, methodCall.Arguments);
                return stream.ToArray();
            }
        }

        /// <InheritDoc/>
        public MethodCall DecodeMethodCall(byte[] methodCall)
        {
            using (var stream = new MemoryStream(methodCall))
            using (var reader = new BinaryReader(stream))
            {
                object method = MessageCodec.ReadValue(reader);
                object arguments = MessageCodec.ReadValue(reader);
                if (method is String strMethod && !stream.HasRemaining())
                {
                    return new MethodCall(strMethod, arguments);
                }
                throw new ArgumentException("Method call corrupted");
            }
        }

        /// <InheritDoc/>
        public byte[] EncodeSuccessEnvelope(object result)
        {
            using (var stream = new MemoryStream())
            using (var writer = new BinaryWriter(stream))
            {
                stream.WriteByte(0);
                MessageCodec.WriteValue(writer, result);
                return stream.ToArray();
            }
        }

        /// <InheritDoc/>
        public byte[] EncodeErrorEnvelope(string errorCode, string errorMessage, object errorDetails)
        {
            return EncodeErrorEnvelope(errorCode, errorMessage, errorDetails, null);
        }

        /// <InheritDoc/>
        public byte[] EncodeErrorEnvelope(string errorCode, string errorMessage, object errorDetails, String errorStacktrace)
        {
            using (var stream = new MemoryStream())
            using (var writer = new BinaryWriter(stream))
            {
                stream.WriteByte(1);
                MessageCodec.WriteValue(writer, errorCode);
                MessageCodec.WriteValue(writer, errorMessage);
                if (errorDetails is Exception exception)
                {
                    MessageCodec.WriteValue(writer, exception.StackTrace);
                }
                else
                {
                    MessageCodec.WriteValue(writer, errorDetails);
                }
                if (!string.IsNullOrEmpty(errorStacktrace))
                {
                    MessageCodec.WriteValue(writer, errorStacktrace);
                }
                return stream.ToArray();
            }
        }

        /// <InheritDoc/>
        public object DecodeEnvelope(byte[] envelope)
        {
            using (var stream = new MemoryStream(envelope))
            using (var reader = new BinaryReader(stream))
            {
                var flag = stream.ReadByte();
                if (flag == 0)
                {
                    var result = MessageCodec.ReadValue(reader);
                    if (stream.HasRemaining())
                    {
                        throw new InvalidOperationException("Envelope corrupted");
                    }
                    return result;
                }
                else if (flag == 1)
                {
                    object code = MessageCodec.ReadValue(reader);
                    object message = MessageCodec.ReadValue(reader);
                    object details = MessageCodec.ReadValue(reader);
                    if (code is String && (message == null || message is String) && !stream.HasRemaining())
                    {
                        throw new FlutterException(code as string, message as string, details);
                    }
                }
                throw new InvalidOperationException("Envelope corrupted");
            }
        }
    }
}

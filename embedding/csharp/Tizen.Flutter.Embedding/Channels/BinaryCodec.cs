// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// <see cref="IMessageCodec{T}"/> with unencoded binary messages.
    /// </summary>
    public class BinaryCodec : IMessageCodec<byte[]>
    {
        /// <InheritDoc/>
        public byte[] EncodeMessage(byte[] message) => message;

        /// <InheritDoc/>
        public byte[] DecodeMessage(byte[] message) => message;
    }
}

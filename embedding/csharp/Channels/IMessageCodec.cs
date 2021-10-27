// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// A message encoding/decoding mechanism.
    /// Both operations throw an exception, if conversion fails, Such situations should be treated as programming errors.
    /// </summary>
    public interface IMessageCodec<T>
    {
        /// <summary>
        /// Encodes the specified message in binary.
        /// </summary>
        /// <param name="message">The message to encode.</param>
        byte[] EncodeMessage(T message);

        /// <summary>
        /// Decodes the specified message from binary.
        /// </summary>
        /// <param name="message">The message to decode.</param>
        T DecodeMessage(byte[] message);
    }

}

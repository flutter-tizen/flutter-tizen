// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// The message codec interface.
    /// </summary>
    public interface IMessageCodec<T>
    {
        /// <summary>
        /// Encodes the message.
        /// </summary>
        /// <param name="message">The message to encode.</param>
        byte[] EncodeMessage(T message);

        /// <summary>
        /// Decodes the message.
        /// </summary>
        /// <param name="message">The message to decode.</param>
        T DecodeMessage(byte[] message);
    }

}

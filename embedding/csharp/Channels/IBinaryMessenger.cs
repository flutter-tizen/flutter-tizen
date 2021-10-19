// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Threading.Tasks;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// A function which takes a platform message and asynchronous returns an encoded response.
    /// </summary>
    public delegate Task<byte[]> BinaryMessageHandler(byte[] data);

    /// <summary>
    /// A messenger which sends binary data across the Flutter platform barrier.
    /// </summary>
    public interface IBinaryMessenger
    {
        /// <summary>
        /// Sends a binary message to the Flutter platform.
        /// </summary>
        /// <param name="channel">The channel to send the message to.</param>
        /// <param name="message">The message to send.</param>
        void Send(string channel, Byte[] message);

        /// <summary>
        /// Sends a binary message to the Flutter platform asynchronously.
        /// </summary>
        /// <param name="channel">The channel to send the message to.</param>
        /// <param name="message">The message to send.</param>
        /// <returns>A task which completes to the response from the Flutter platform.</returns>
        Task<byte[]> SendAsync(string channel, byte[] message);

        /// <summary>
        /// Sets a callback for a binary message channel.
        /// </summary>
        /// <param name="channel">The channel to listen on.</param>
        /// <param name="handler">The callback to invoke when a message is received.</param>
        void SetMessageHandler(string channel, BinaryMessageHandler handler);
    }
}
// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Threading.Tasks;

namespace Tizen.Flutter.Embedding
{
    public class BasicMessageChannel
    {
        public static BasicMessageChannel<T> Create<T>(string name, IMessageCodec<T> codec, IBinaryMessenger messenger)
        {
            return new BasicMessageChannel<T>(name, codec, messenger);
        }

        public static BasicMessageChannel<T> Create<T>(string name, IMessageCodec<T> codec)
        {
            var messenger = DefaultBinaryMessenger.Instance;
            if (messenger == null)
            {
                throw new InvalidOperationException("DefaultBinaryMessenger is not initialized.");
            }
            return new BasicMessageChannel<T>(name, codec, messenger);
        }
    }

    /// <summary>
    /// A channel that communicates with the Flutter framework.
    /// </summary>
    public class BasicMessageChannel<T>
    {
        private readonly IBinaryMessenger _messenger;
        private readonly string _name;
        private readonly IMessageCodec<T> _codec;

        /// <summary>
        /// Initializes a new instance of the <see cref="BasicMessageChannel{T}"/> class.
        /// </summary>
        public BasicMessageChannel(string name, IMessageCodec<T> codec, IBinaryMessenger messenger)
        {
            _messenger = messenger;
            _name = name;
            _codec = codec;
        }

        /// <summary>
        /// Sends a message to the Flutter framework.
        /// </summary>
        /// <param name="message">The message to send.</param>
        public void Send(T message)
        {
            _messenger.Send(_name, _codec.EncodeMessage(message));
        }

        /// <summary>
        /// Sends a message to the Flutter framework asynchronously.
        /// </summary>
        /// <param name="message">The message to send.</param>
        /// <returns>A task that completes with the response message.</returns>
        public async Task<T> SendAsync(T message)
        {
            var replyBytes = await _messenger.SendAsync(_name, _codec.EncodeMessage(message));
            return _codec.DecodeMessage(replyBytes);
        }

        /// <summary>
        /// Sets a callback that is invoked when a message is received from the Flutter framework.
        /// </summary>
        /// <param name="callback">The callback to invoke when a message is received.</param>
        public void SetMessageHandler(Func<T, Task<T>> handler)
        {
            _messenger.SetMessageHandler(_name, async (bytes) =>
            {
                var message = _codec.DecodeMessage(bytes);
                var reply = await handler(message);
                return _codec.EncodeMessage(reply);
            });
        }
    }
}
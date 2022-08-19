// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Threading.Tasks;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// A named channel for communicating with the Flutter application using asynchronous event streams.
    /// </summary>
    public class EventChannel
    {
        /// <summary>
        /// Creates a new channel associated with the specified name and with the standard <see cref="IMethodCodec"/>
        /// and the default <see cref="IBinaryMessenger"/>.
        /// </summary>
        /// <param name="name">A channel name string.</param>
        public EventChannel(string name) : this(name, StandardMethodCodec.Instance)
        {
        }

        /// <summary>
        /// Creates a new channel associated with the specified name and with the specified <see cref="IMethodCodec"/>
        /// and the default <see cref="IBinaryMessenger"/>.
        /// </summary>
        /// <param name="name">A channel name string.</param>
        /// <param name="codec">A <see cref="IMethodCodec"/>.</param>
        public EventChannel(string name, IMethodCodec codec) : this(name, codec, DefaultBinaryMessenger.Instance)
        {
        }

        /// <summary>
        /// Creates a new channel associated with the specified name and with the specified <see cref="IMethodCodec"/>
        /// and the specified <see cref="IBinaryMessenger"/>.
        /// </summary>
        /// <param name="name">A channel name string.</param>
        /// <param name="codec">A <see cref="IMethodCodec"/>.</param>
        /// <param name="messenger">A <see cref="IBinaryMessenger"/>.</param>
        public EventChannel(string name, IMethodCodec codec, IBinaryMessenger messenger)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new ArgumentException("name cannot be null or empty");
            }
            Name = name;
            Codec = codec ?? throw new ArgumentNullException(nameof(codec));
            BinaryMessenger = messenger ?? throw new ArgumentNullException(nameof(messenger));
        }

        /// <summary>
        /// The logical channel on which communication happens, not null.
        /// </summary>
        public string Name { get; }

        /// <summary>
        /// The method codec used by this channel, not null.
        /// </summary>
        public IMethodCodec Codec { get; }

        /// <summary>
        /// The messenger used by this channel to send messages.
        /// </summary>
        public IBinaryMessenger BinaryMessenger { get; }

        /// <summary>
        /// Registers a stream handler on this channel.
        /// </summary>
        /// <param name="handler">A <see cref="IEventStreamHandler"/>, or null to deregister.</param>
        public void SetStreamHandler(IEventStreamHandler handler)
        {
            BinaryMessageHandler binaryHandler = null;
            if (handler != null)
            {
                binaryHandler = new IncomingStreamRequestHandler(this, handler).OnMessage;
            }
            BinaryMessenger.SetMessageHandler(Name, binaryHandler);
        }
    }

    class IncomingStreamRequestHandler
    {
        private readonly EventChannel _channel;
        private readonly IEventStreamHandler _handler;
        private IEventSink _activeSink;

        public IncomingStreamRequestHandler(EventChannel channel, IEventStreamHandler handler)
        {
            _channel = channel;
            _handler = handler;
        }

        public Task<byte[]> OnMessage(byte[] message)
        {
            MethodCall call = _channel.Codec.DecodeMethodCall(message);
            if (call.Method == "listen")
            {
                return OnListen(call);
            }
            else if (call.Method == "cancel")
            {
                return OnCancel(call);
            }
            return Task.FromResult<byte[]>(null);
        }

        private Task<byte[]> OnListen(MethodCall call)
        {
            if (_activeSink != null)
            {
                try
                {
                    _handler.OnCancel(null);
                }
                catch (Exception e)
                {
                    TizenLog.Error($"{_channel.Name}: Failed to close existing event stream. {e.Message}");
                }
            }
            try
            {
                _activeSink = new EventSinkImpl(this);
                _handler.OnListen(call.Arguments, _activeSink);
                return Task.FromResult(_channel.Codec.EncodeSuccessEnvelope(null));
            }
            catch (Exception e)
            {
                _activeSink = null;
                TizenLog.Error($"{_channel.Name}: Failed to open event stream. {e.Message}");
                return Task.FromResult(_channel.Codec.EncodeErrorEnvelope("error", e.Message, null));
            }
        }

        private Task<byte[]> OnCancel(MethodCall call)
        {
            if (_activeSink != null)
            {
                try
                {
                    _handler.OnCancel(call.Arguments);
                    return Task.FromResult(_channel.Codec.EncodeSuccessEnvelope(null));
                }
                catch (Exception e)
                {
                    TizenLog.Error($"{_channel.Name}: Failed to close event stream. {e.Message}");
                    return Task.FromResult(_channel.Codec.EncodeErrorEnvelope("error", e.Message, null));
                }
            }
            else
            {
                return Task.FromResult(
                    _channel.Codec.EncodeErrorEnvelope("error", "No active stream to cancel.", null));
            }
        }

        class EventSinkImpl : IEventSink
        {
            private readonly IncomingStreamRequestHandler _requestHandler;
            private bool hasEnded = false;

            public EventSinkImpl(IncomingStreamRequestHandler requestHandler)
            {
                _requestHandler = requestHandler;
            }

            private EventChannel Channel => _requestHandler._channel;

            public void Success(object @event)
            {
                if (hasEnded || _requestHandler._activeSink != this)
                {
                    return;
                }
                Channel.BinaryMessenger.Send(Channel.Name, Channel.Codec.EncodeSuccessEnvelope(@event));
            }

            public void Error(string code, string message, object details)
            {
                if (hasEnded || _requestHandler._activeSink != this)
                {
                    return;
                }
                Channel.BinaryMessenger.Send(Channel.Name, Channel.Codec.EncodeErrorEnvelope(code, message, details));
            }

            public void EndOfStream()
            {
                if (hasEnded || _requestHandler._activeSink != this)
                {
                    return;
                }
                hasEnded = true;
                Channel.BinaryMessenger.Send(Channel.Name, null);
            }
        }
    }
}

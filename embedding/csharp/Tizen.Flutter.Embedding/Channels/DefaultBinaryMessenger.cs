// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Tizen.Applications;
using static Tizen.Flutter.Embedding.Interop;

namespace Tizen.Flutter.Embedding
{
    internal class DefaultBinaryMessenger : IBinaryMessenger
    {
        private static DefaultBinaryMessenger _instance;
        private static readonly object _lock = new object();
        private readonly FlutterDesktopMessenger _messenger;
        private readonly Dictionary<string, BinaryMessageHandler> _handlers =
            new Dictionary<string, BinaryMessageHandler>();
        private readonly Dictionary<int, TaskCompletionSource<byte[]>> _replyCallbackSources =
            new Dictionary<int, TaskCompletionSource<byte[]>>();
        private readonly FlutterDesktopBinaryReply _replyCallback;
        private readonly FlutterDesktopMessageCallback _messageCallback;

        private int _replyCallbackId = 0;

        private DefaultBinaryMessenger(FlutterDesktopMessenger messenger)
        {
            _messenger = messenger;
            _replyCallback = OnReplyMessageReceived;
            _messageCallback = OnMessageReceived;
        }

        public static DefaultBinaryMessenger Instance
        {
            get
            {
                lock (_lock)
                {
                    if (_instance == null)
                    {
                        if (Application.Current is FlutterApplication app)
                        {
                            _instance = new DefaultBinaryMessenger(app.Engine.GetMessenger());
                        }
                        else if (Application.Current is FlutterServiceApplication service)
                        {
                            _instance = new DefaultBinaryMessenger(service.Engine.GetMessenger());
                        }
                    }
                    return _instance;
                }
            }
        }

        public void Send(string channel, byte[] message)
        {
            if (message == null)
            {
                FlutterDesktopMessengerSend(_messenger, channel, IntPtr.Zero, 0);
                return;
            }
            using (var pinned = PinnedObject.Get(message))
            {
                FlutterDesktopMessengerSend(_messenger, channel, pinned.Pointer, (uint)message.Length);
            }
        }

        public Task<byte[]> SendAsync(string channel, byte[] message)
        {
            var tcs = new TaskCompletionSource<byte[]>();
            int replyId;
            lock (_replyCallbackSources)
            {
                replyId = _replyCallbackId++;
                _replyCallbackSources.Add(replyId, tcs);
            }
            if (message == null)
            {
                FlutterDesktopMessengerSendWithReply(
                    _messenger, channel, IntPtr.Zero, 0, _replyCallback, (IntPtr)replyId);
                return tcs.Task;
            }
            using (var pinned = PinnedObject.Get(message))
            {
                FlutterDesktopMessengerSendWithReply(
                    _messenger, channel, pinned.Pointer, (uint)message.Length, _replyCallback, (IntPtr)replyId);
            }
            return tcs.Task;
        }

        public void SetMessageHandler(string channel, BinaryMessageHandler handler)
        {
            if (handler == null)
            {
                _handlers.Remove(channel);
                FlutterDesktopMessengerSetCallback(_messenger, channel, null, IntPtr.Zero);
                return;
            }
            _handlers[channel] = handler;
            FlutterDesktopMessengerSetCallback(_messenger, channel, _messageCallback, IntPtr.Zero);
        }

        private void OnReplyMessageReceived(IntPtr message, uint messageSize, IntPtr userData)
        {
            int replyId = (int)userData;
            if (_replyCallbackSources.TryGetValue(replyId, out TaskCompletionSource<byte[]> tcs))
            {
                _replyCallbackSources.Remove(replyId);
                byte[] replyBytes = new byte[messageSize];
                Marshal.Copy(message, replyBytes, 0, (int)messageSize);
                tcs.TrySetResult(replyBytes);
            }
        }

        private async void OnMessageReceived(FlutterDesktopMessenger messenger, IntPtr message, IntPtr userData)
        {
            var receivedMessage = Marshal.PtrToStructure<FlutterDesktopMessage>(message);
            var messageBytes = new byte[receivedMessage.message_size];
            Marshal.Copy(receivedMessage.message, messageBytes, 0, (int)receivedMessage.message_size);
            if (_handlers.TryGetValue(receivedMessage.channel, out var handler))
            {
                byte[] replyBytes = await handler(messageBytes);
                if (replyBytes != null)
                {
                    using (var pinned = PinnedObject.Get(replyBytes))
                    {
                        FlutterDesktopMessengerSendResponse(
                            messenger, receivedMessage.response_handle, pinned.Pointer, (uint)replyBytes.Length);
                    }
                }
                else
                {
                    FlutterDesktopMessengerSendResponse(messenger, receivedMessage.response_handle, IntPtr.Zero, 0);
                }
            }
            else
            {
                FlutterDesktopMessengerSendResponse(messenger, receivedMessage.response_handle, IntPtr.Zero, 0);
            }
        }
    }
}

// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Handler of stream setup and teardown requests.
    /// </summary>
    public class EventStreamHandler : IEventStreamHandler
    {
        private readonly Action<object, IEventSink> _onListenHandler;
        private readonly Action<object> _onCancelHandler;

        /// <summary>
        /// Creates an <see cref="IEventStreamHandler"/> with callbacks.
        /// </summary>
        /// <param name="onListen">A callback to set up an event stream.</param>
        /// <param name="onCancel">A callback to tear down the most recently created event stream.</param>
        public EventStreamHandler(Action<object, IEventSink> onListen, Action<object> onCancel)
        {
            _onListenHandler = onListen;
            _onCancelHandler = onCancel;
        }

        /// <InheritDoc/>
        public void OnListen(object arguments, IEventSink events)
        {
            _onListenHandler(arguments, events);
        }

        /// <InheritDoc/>
        public void OnCancel(object arguments)
        {
            _onCancelHandler(arguments);
        }
    }
}

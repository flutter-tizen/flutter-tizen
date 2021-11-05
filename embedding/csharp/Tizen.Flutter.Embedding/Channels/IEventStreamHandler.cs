// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Handler of stream setup and teardown requests.
    /// </summary>
    public interface IEventStreamHandler
    {
        /// <summary>
        /// Handles a request to set up an event stream.
        /// </summary>
        /// <param name="arguments">Stream configuration arguments, possibly null.</param>
        /// <param name="events">An <see cref="IEventSink"/> for emitting events to the Flutter receiver.</param>
        void OnListen(object arguments, IEventSink events);

        /// <summary>
        /// Handles a request to tear down the most recently created event stream.
        /// </summary>
        /// <param name="arguments">Stream configuration arguments, possibly null.</param>
        void OnCancel(object arguments);
    }
}

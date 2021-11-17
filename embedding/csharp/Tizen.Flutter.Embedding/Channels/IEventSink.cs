// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Event callback.
    /// </summary>
    public interface IEventSink
    {
        /// <summary>
        /// Consumes a successful event.
        /// </summary>
        /// <param name="event">The event, possibly null.</param>
        void Success(object @event);

        /// <summary>
        /// Consumes an error event.
        /// </summary>
        /// <param name="code">An error code string.</param>
        /// <param name="message">A human-readable error message string, possibly null.</param>
        /// <param name="details">Error details, possibly null.</param>
        void Error(string code, string message, object details);

        /// <summary>
        /// Consumes end of stream. 
        /// <para>Ensuing calls to <see cref="Success(object)"/> or <see cref="Error(string, string, object)"/>, if any, are ignored.</para>
        /// </summary>
        void EndOfStream();
    }
}

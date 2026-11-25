// Copyright 2026 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using Xunit;

namespace Tizen.Flutter.Embedding.Tests.Channels
{
    public class PlatformMessageTests
    {
        [Fact]
        public void DistinguishesANullPayloadFromAnEmptyPayload()
        {
            var message = new Interop.FlutterDesktopMessage();
            Assert.Null(message.GetMessageBytes());

            using (var buffer = PinnedObject.Get(new byte[] { 42 }))
            {
                message.message = buffer.Pointer;
                Assert.Empty(message.GetMessageBytes());

                message.message_size = 1;
                Assert.Equal(new byte[] { 42 }, message.GetMessageBytes());
            }
        }
    }
}

// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Runtime.InteropServices;

namespace Tizen.Flutter.Embedding
{
    public class FlutterWindowControllerHandle : SafeHandle
    {
        public FlutterWindowControllerHandle() : base(IntPtr.Zero, true)
        {
        }

        public override bool IsInvalid => handle == IntPtr.Zero;

        public static implicit operator bool(FlutterWindowControllerHandle window)
        {
            return !window.IsInvalid;
        }

        protected override bool ReleaseHandle()
        {
            SetHandle(IntPtr.Zero);
            return true;
        }
    }
}

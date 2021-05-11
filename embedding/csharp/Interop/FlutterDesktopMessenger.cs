// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Runtime.InteropServices;

namespace Tizen.Flutter.Embedding
{
    public class FlutterDesktopMessenger : SafeHandle
    {
        public FlutterDesktopMessenger() : base(IntPtr.Zero, true)
        {
        }

        public override bool IsInvalid => handle == IntPtr.Zero;

        protected override bool ReleaseHandle()
        {
            SetHandle(IntPtr.Zero);
            return true;
        }

        internal class Marshaler : ICustomMarshaler
        {
            private static readonly Marshaler _instance = new Marshaler();

            public void CleanUpManagedData(object ManagedObj)
            {
            }

            public void CleanUpNativeData(IntPtr pNativeData)
            {
            }

            public int GetNativeDataSize()
            {
                return IntPtr.Size;
            }

            public IntPtr MarshalManagedToNative(object ManagedObj)
            {
                if (ManagedObj is FlutterDesktopMessenger messenger)
                {
                    return messenger.handle;
                }
                return IntPtr.Zero;
            }

            public object MarshalNativeToManaged(IntPtr pNativeData)
            {
                return new FlutterDesktopMessenger()
                {
                    handle = pNativeData
                };
            }

            public static ICustomMarshaler GetInstance(string s)
            {
                return _instance;
            }
        }
    }
}

// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Runtime.InteropServices;

namespace Tizen.Flutter.Embedding
{
    internal abstract class PinnedObject : IDisposable
    {
        private PinnedObject()
        {
        }

        public abstract void Dispose();

        public static PinnedObjectImpl<T> Get<T>(T target)
        {
            return new PinnedObjectImpl<T>(target);
        }

        internal class PinnedObjectImpl<T> : PinnedObject
        {
            private readonly GCHandle _handle;

            internal PinnedObjectImpl(T obj)
            {
                Target = obj;
                _handle = GCHandle.Alloc(obj, GCHandleType.Pinned);
            }

            ~PinnedObjectImpl()
            {
                Dispose(false);
            }

            private bool _disposed = false;

            protected virtual void Dispose(bool disposing)
            {
                if (!_disposed)
                {
                    if (disposing)
                    {
                        _handle.Free();
                    }
                    _disposed = true;
                }
            }

            public override void Dispose()
            {
                Dispose(true);
                GC.SuppressFinalize(this);
            }

            public T Target { get; }

            public IntPtr Pointer => _handle.AddrOfPinnedObject();
        }
    }
}

// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Re-allocates an array of managed strings for unmanaged access.
    /// </summary>
    public sealed class StringArray : IDisposable
    {
        private readonly List<GCHandle> _handles = new List<GCHandle>();

        public StringArray(IEnumerable<string> managed)
        {
            var pointers = new List<IntPtr>();
            foreach (var str in managed)
            {
                var bytes = Encoding.ASCII.GetBytes(str);
                var handle = GCHandle.Alloc(bytes, GCHandleType.Pinned);
                _handles.Add(handle);
                pointers.Add(handle.AddrOfPinnedObject());
            }
            _handles.Add(GCHandle.Alloc(pointers.ToArray(), GCHandleType.Pinned));
        }

        /// <summary>
        /// The length of the array. Returns -1 if invalid.
        /// </summary>
        public int Length => _handles.Count - 1;

        /// <summary>
        /// The address of the underlying native array.
        /// </summary>
        public IntPtr Handle => _handles.Count > 0 ? _handles[Length].AddrOfPinnedObject() : IntPtr.Zero;

        public void Dispose()
        {
            foreach (var handle in _handles)
            {
                handle.Free();
            }
            _handles.Clear();
        }
    }
}

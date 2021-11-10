// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Threading.Tasks;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// A handler of incoming method calls.
    /// </summary>
    /// <param name="call">A <see cref="MethodCall"/>.</param>
    /// <returns>A result used for submitting the result of the call.</returns>
    public delegate Task<object> MethodCallHandler(MethodCall call);

    /// <summary>
    /// A named channel for communicating with the Flutter application using asynchronous method calls.
    /// </summary>
    public class MethodChannel
    {
        /// <summary>
        /// Creates a new channel associated with the specified name and the standard <see cref="IMethodCodec"/>
        /// and the default <see cref="IBinaryMessenger"/>.
        /// </summary>
        /// <param name="name">A channel name string.</param>
        public MethodChannel(string name)
            : this(name, StandardMethodCodec.Instance)
        {
        }

        /// <summary>
        /// Creates a new channel associated with the specified name and the specified <see cref="IMethodCodec"/>
        /// and the default <see cref="IBinaryMessenger"/>.
        /// </summary>
        /// <param name="name">A channel name string.</param>
        /// <param name="codec">A <see cref="IMethodCodec"/>.</param>
        public MethodChannel(string name, IMethodCodec codec)
            : this(name, codec, DefaultBinaryMessenger.Instance)
        {
        }

        /// <summary>
        /// Creates a new channel associated with the specified name and the specified <see cref="IMethodCodec"/>
        /// and the specified <see cref="IBinaryMessenger"/>.
        /// </summary>
        /// <param name="name">A channel name string.</param>
        /// <param name="codec">A <see cref="IMethodCodec"/>.</param>
        /// <param name="messenger">A <see cref="IBinaryMessenger"/>.</param>
        public MethodChannel(string name, IMethodCodec codec, IBinaryMessenger messenger)
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
        /// Invokes a method on this channel, expecting no result.
        /// </summary>
        /// <param name="method">The name string of the method.</param>
        /// <param name="arguments">The arguments for the invocation, possibly null.</param>
        public void InvokeMethod(string method, object arguments)
        {
            InvokeMethod(new MethodCall(method, arguments));
        }

        /// <summary>
        /// Invokes a method on this channel, expecting no result.
        /// </summary>
        /// <param name="call">A <see cref="MethodCall"/>.</param>
        public void InvokeMethod(MethodCall call)
        {
            if (call == null)
            {
                throw new ArgumentNullException(nameof(call));
            }
            BinaryMessenger.Send(Name, Codec.EncodeMethodCall(call));
        }

        /// <summary>
        /// Invokes a method on this channel, expecting a result.
        /// </summary>
        /// <remarks>
        /// A <see cref="FlutterException"/> is thrown, if the invocation failed in the Flutter application.
        /// </remarks>
        /// <param name="method">The name string of the method.</param>
        /// <param name="arguments">The arguments for the invocation, possibly null.</param>
        /// <returns>A <see cref="Task"/> that completes with a result.</returns>
        public Task<object> InvokeMethodAsync(string method, object arguments)
        {
            return InvokeMethodAsync(new MethodCall(method, arguments));
        }

        /// <summary>
        /// Invokes a method on this channel, expecting a result.
        /// </summary>
        /// <remarks>
        /// A <see cref="FlutterException"/> is thrown, if the invocation failed in the Flutter application.
        /// </remarks>
        /// <param name="call">A <see cref="MethodCall"/>.</param>
        /// <returns>A <see cref="Task"/> that completes with a result.</returns>
        public async Task<object> InvokeMethodAsync(MethodCall call)
        {
            if (call == null)
            {
                throw new ArgumentNullException(nameof(call));
            }
            byte[] result = await BinaryMessenger.SendAsync(Name, Codec.EncodeMethodCall(call));
            return Codec.DecodeEnvelope(result);
        }

        /// <summary>
        /// Registers a method call handler on this channel.
        /// </summary>
        /// <param name="handler">A <see cref="MethodCallHandler"/>, or null to deregister.</param>
        public void SetMethodCallHandler(MethodCallHandler handler)
        {
            async Task<byte[]> binaryHandler(byte[] bytes)
            {
                MethodCall call = Codec.DecodeMethodCall(bytes);
                try
                {
                    return Codec.EncodeSuccessEnvelope(await handler(call));
                }
                catch (FlutterException e)
                {
                    return Codec.EncodeErrorEnvelope(e.Code, e.Message, e.Details, e.StackTrace);
                }
                catch (MissingPluginException)
                {
                    return null;
                }
                catch (Exception e)
                {
                    return Codec.EncodeErrorEnvelope("error", e.Message, null, e.StackTrace);
                }
            }
            BinaryMessenger.SetMessageHandler(Name, handler == null ? null : (BinaryMessageHandler)binaryHandler);
        }
    }
}

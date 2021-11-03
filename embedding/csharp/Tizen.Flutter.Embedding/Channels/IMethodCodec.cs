// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// A codec for method calls and enveloped results.
    /// </summary>
    public interface IMethodCodec
    {
        /// <summary>
        /// Encodes a message call into binary.
        /// </summary>
        /// <param name="methodCall">A <see cref="MethodCall"/></param>
        /// <returns>A byte array containing the encoding.</returns>
        byte[] EncodeMethodCall(MethodCall methodCall);

        /// <summary>
        /// Decodes a message call from binary.
        /// </summary>
        /// <param name="methodCall">The binary encoding of the method call as a byte array.</param>
        /// <returns>A <see cref="MethodCall"/> representation of the bytes.</returns>
        MethodCall DecodeMethodCall(byte[] methodCall);

        /// <summary>
        /// Encodes a successful result into a binary envelope message.
        /// </summary>
        /// <param name="result">The result value, possibly null.</param>
        /// <returns>A byte array containing the encoding.</returns>
        byte[] EncodeSuccessEnvelope(object result);

        /// <summary>
        /// Encodes an error result into a binary envelope message.
        /// </summary>
        /// <param name="errorCode">An error code string.</param>
        /// <param name="errorMessage">An error message String, possibly null.</param>
        /// <param name="errorDetails">Error details, possibly null. Consider supporting
        /// <see cref="Exception"/>in your codec.This is the most common value passed to this field.</param>
        /// <returns>A byte array containing the encoding.</returns>
        byte[] EncodeErrorEnvelope(string errorCode, string errorMessage, object errorDetails);

        /// <summary>
        /// Encodes an error result into a binary envelope message.
        /// </summary>
        /// <param name="errorCode">An error code string.</param>
        /// <param name="errorMessage">An error message String, possibly null.</param>
        /// <param name="errorDetails">Error details, possibly null. Consider supporting
        /// <see cref="Exception"/>in your codec.This is the most common value passed to this field.</param>
        /// <param name="errorStacktrace">Platform stacktrace for the error. possibly null.</param>
        /// <returns>A byte array containing the encoding.</returns>
        byte[] EncodeErrorEnvelope(string errorCode, string errorMessage, object errorDetails, string errorStacktrace);

        /// <summary>
        /// Decodes a result envelope from binary.
        /// </summary>
        /// <param name="envelope">The binary encoding of a result envelope as a byte array.</param>
        /// <returns>The enveloped result Object.</returns>
        object DecodeEnvelope(byte[] envelope);
    }
}

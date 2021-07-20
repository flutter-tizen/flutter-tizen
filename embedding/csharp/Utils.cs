// Copyright 2021 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.IO;
using Tizen.Applications;

namespace Tizen.Flutter.Embedding
{
    internal static class Utils
    {
        /// <summary>
        /// Reads engine arguments passed from the flutter-tizen tool and adds to <paramref name="list"/>.
        /// </summary>
        public static void ParseEngineArgs(IList<string> list)
        {
            string appId = Application.Current.ApplicationInfo.ApplicationId;
            string tempPath = $"/home/owner/share/tmp/sdk_tools/{appId}.rpm";
            if (!File.Exists(tempPath))
            {
                return;
            }
            try
            {
                var lines = File.ReadAllText(tempPath).Trim().Split("\n");
                foreach (string line in lines)
                {
                    TizenLog.Info($"Enabled: {line}");
                    list.Add(line);
                }
                File.Delete(tempPath);
            }
            catch (Exception ex)
            {
                TizenLog.Warn($"Error while processing a file: {ex}");
            }
        }
    }
}

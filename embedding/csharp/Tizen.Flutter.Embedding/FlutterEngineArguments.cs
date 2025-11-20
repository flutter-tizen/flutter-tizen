// Copyright 2025 Samsung Electronics Co., Ltd. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

using System;
using System.Collections.Generic;
using System.IO;
using Tizen.Applications;

namespace Tizen.Flutter.Embedding
{
    /// <summary>
    /// Handles parsing and management of Flutter engine arguments.
    /// </summary>
    public class FlutterEngineArguments
    {
        private const string MetadataKeyEnableImepeller = "http://tizen.org/metadata/flutter_tizen/enable_impeller";
        private const string MetadataKeyEnableFlutterGpu = "http://tizen.org/metadata/flutter_tizen/enable_flutter_gpu";

        /// <summary>
        /// Gets the list of parsed engine arguments.
        /// </summary>
        public IList<string> Arguments { get; private set; }

        /// <summary>
        /// Gets whether the impeller is enabled or not.
        /// </summary>
        public bool IsImpellerEnabled { get; private set; } = false;

        /// <summary>
        /// Gets whether the flutter gpu is enabled or not.
        /// </summary>
        public bool IsFlutterGpuEnabled { get; private set; } = false;

        /// <summary>
        /// Gets whether the flutter tizen experimental is enabled or not.
        /// </summary>
        public bool IsFlutterTizenExperimentalEnabled { get; private set; } = false;

        /// <summary>
        /// Creates a <see cref="FlutterEngineArguments"/> instance and parses engine arguments.
        /// </summary>
        public FlutterEngineArguments()
        {
            Arguments = ParseEngineArgs();
        }

        /// <summary>
        /// Reads engine arguments passed from the flutter-tizen tool.
        /// </summary>
        private IList<string> ParseEngineArgs()
        {
            var result = new List<string>();
            string appId = Application.Current.ApplicationInfo.ApplicationId;
            string tempPath = $"/home/owner/share/tmp/sdk_tools/{appId}.rpm";

            if (File.Exists(tempPath))
            {
                try
                {
                    var lines = File.ReadAllText(tempPath).Trim().Split('\n');
                    foreach (string line in lines)
                    {
                        result.Add(line);
                    }
                    File.Delete(tempPath);
                }
                catch (Exception ex)
                {
                    TizenLog.Warn($"Error while processing a file: {ex}");
                }
            }

            IsImpellerEnabled = ProcessMetadataFlag(result, "--enable-impeller", MetadataKeyEnableImepeller);
            IsFlutterGpuEnabled = ProcessMetadataFlag(result, "--enable-flutter-gpu", MetadataKeyEnableFlutterGpu);
            IsFlutterTizenExperimentalEnabled = result.Contains("--dart-define=USE_FLUTTER_TIZEN_EXPERIMENTAL=true");

            foreach (string flag in result)
            {
                TizenLog.Info($"Enabled: {flag}");
            }
            return result;
        }

        /// <summary>
        /// Processes a metadata flag by checking both engine arguments and application metadata.
        /// </summary>
        private static bool ProcessMetadataFlag(List<string> result, string flag, string metadataKey)
        {
            var appInfo = Application.Current.ApplicationInfo;
            bool enabled = false;
            bool flagExists = result.Contains(flag);
            if (flagExists)
            {
                enabled = true;
            }

            if (appInfo.Metadata.TryGetValue(metadataKey, out string metadataValue))
            {
                bool metadataEnabled = metadataValue == "true";

                if (!flagExists && metadataEnabled)
                {
                    enabled = true;
                    result.Insert(0, flag);
                }
                else if (flagExists && !metadataEnabled)
                {
                    enabled = false;
                    result.Remove(flag);
                }
            }
            return enabled;
        }
    }
}

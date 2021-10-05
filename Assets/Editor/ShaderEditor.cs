using System;
using System.Collections;
using UnityEngine;
using UnityEditor;
using UnityEditor.Callbacks;
public class AssetOpenModeWindow : EditorWindow
{

    [OnOpenAsset(1)]
    public static bool step1(int instanceID, int line)
    {
        string strFilePath = AssetDatabase.GetAssetPath(EditorUtility.InstanceIDToObject(instanceID));
        string strFileName = System.IO.Directory.GetParent(Application.dataPath) + "/" + strFilePath;
        if (strFileName.EndsWith(".shader") || strFileName.EndsWith(".cginc"))
        {
            //自行添加Sublime的环境变量
            string strSublimeTextPath = Environment.GetEnvironmentVariable("SublimeText_Path");


            if (strSublimeTextPath != null && strSublimeTextPath.Length > 0)
            {
                System.Diagnostics.Process process = new System.Diagnostics.Process();
                System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo();
                startInfo.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
                startInfo.FileName = strSublimeTextPath + (strSublimeTextPath.EndsWith("/") ? "" : "/") +
                                     "sublime_text.exe";
                startInfo.Arguments = "\"" + strFileName + "\"";
                process.StartInfo = startInfo;
                process.Start();


                return true;
            }
            else
            {
                Debug.Log("Not Found Enviroment Variable 'SublimeText_Path'.");

                return false;
            }
        }

        return false;
    }

}
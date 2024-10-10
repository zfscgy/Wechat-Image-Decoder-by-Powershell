$decryptor_source = @"
using System;
using System.IO;

public class DecryptorResult {
    public string Ext {get; set;}
    public byte Key {get; set;}
    public DecryptorResult(string ext, byte key) {
        this.Ext = ext;
        this.Key = key;
    }
}

public class XORDecryptor {
    public static DecryptorResult DecryptOneFile (string inputFile, string outputFile) {
        byte[] jpeg_head = { 0xFF, 0xD8, 0xFF };
        byte[] png_head = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
        byte[] gif_head = { (byte)'G', (byte)'I', (byte)'F' };
        byte[] webp_head = {(byte)'R', (byte)'I', (byte)'F', (byte)'F'};

        byte[][] file_heads = {jpeg_head, png_head, gif_head, webp_head};
        string[] file_exts = {"jpg", "png", "gif", "webp"};
        
        // Read the input file as a byte array
        byte[] fileBytes = File.ReadAllBytes(inputFile);

        byte key = 0x00;      // No key is found, so bxor with zero to keep the orginal file
        string ext = "datbak";  // original Wechat encrypted format (with bak as posfix)

        for(int i = 0; i < file_heads.Length; i++) {
            byte[] file_head = file_heads[i];
            byte key0 = (byte)(fileBytes[0] ^ file_head[0]);
            bool check = true;
            for (int j = 1; j < file_head.Length; j++) {
                if ((byte)(fileBytes[j] ^ key0) != file_head[j]) {
                    check = false;
                    break;
                }
            }
            if (check) {
                key = key0;
                ext = file_exts[i];
                break;
            }
        }

        for(int i = 0; i < fileBytes.Length; i++) {
            fileBytes[i] = (byte)(fileBytes[i] ^ key);
        }

        File.WriteAllBytes(outputFile + "." + ext, fileBytes);
        return new DecryptorResult(ext, key);
    }
}

"@

Add-Type -TypeDefinition $decryptor_source


Write-Host "
=============================================================
    微信图片文件提取工具，开发者：Free Engineer，zf6792@163.com
    该工具会解码微信聊天记录文件夹中【Wechat Files】的图片文件，并且将其转移到【ZF_处理后图片】文件夹，按【年-月】的方式存储，文件名表示微信下载该图片的时间。
    使用该工具，可以方便管理微信聊天记录中的图片，节省电脑空间。当所有图片转移后，可以删除微信文件夹中对应的【Image】、【MsgAttach】文件夹。
    本工具也可能找到已删除的聊天记录中的图片（微信中无法找到）。
    注：尽管图片被解码并转移，但是删除上述两个文件夹后，微信的聊天中会出现图片无法加载的情况，因此请谨慎清理。
===============================================================
"


if (!(Test-Path -Path "./Image") -and !(Test-Path -Path "./MsgAttach")) {
    Write-Host "【错误】未检测到微信文件夹，请将该脚本放入微信文件夹（Wechat Files），具体路径位置在【微信-设置-文件管理】查看" -ForegroundColor 'RED'
    Exit
}

$export_path = "$((Get-Item .).FullName)\ZF_处理后图片"
Write-Host "导出文件地址：$export_path"
# New-Item $export_path -Type Directory


if (Test-Path -Path $export_path) {
    Write-Host "导出文件地址已经存在！" -ForegroundColor 'RED'
    Read-Host "请点击任意键继续，如不想继续，请直接关闭Powershell窗口 或 按Ctrl + C退出"
}


Write-Host "
===================================
    开始处理图片数据...
===================================
"

$mapping_file_path = "$export_path\路径对应关系.txt"
$null = New-Item -Force -Path $mapping_file_path -Type File

Write-Host "处理 2022-06 之前的图片数据..."

$month_dirs = Get-ChildItem -Path ".\Image\" -Directory

# Iterate through each file
$month_dir_cnt = 0
foreach ($month_dir in $month_dirs) {
    Write-Progress -Id 0 -Activity "读取2022-06之前的数据" -Status "$($month_dir_cnt * 100 / $month_dirs.Count)%" -PercentComplete ($month_dir_cnt  * 100 / $month_dirs.Count)

    $null = New-Item -Force -Path "$export_path\$month_dir" -Type Directory

    $file_cnt = 0
    foreach ($file in (Get-ChildItem -Path $month_dir.FullName -File)) {
        $formattedDate = $file.CreationTime.ToString("yyyyMMdd")
        $output_file_prefix = "$export_path\$month_dir\$formattedDate-$file_cnt"
        # Convert the file to a byte array
        $res = [XORDecryptor]::DecryptOneFile($file.FullName, $output_file_prefix)
        
        $output_file_path = $output_file_prefix + "." + $res.Ext
        $file_cnt++

        Write-Output "$($file.FullName),$output_file_path,$($res.Key)" >> $mapping_file_path
    }
    $month_dir_cnt++
}

Write-Host "处理 2022-06 之后的图片数据..."

$msg_dirs = Get-ChildItem -Path ".\MsgAttach\" -Directory

$msg_dir_cnt = 0
foreach($msg_dir in $msg_dirs) {
    Write-Progress -Id 1 -Activity "读取2022-06之后的数据" -Status "$($msg_dir_cnt * 100 / $msg_dirs.Count)%" -PercentComplete ($msg_dir_cnt  * 100 / $msg_dirs.Count)
    if (!(Test-Path -Path "$($msg_dir.FullName)\Image")) {
        continue
    }
    $month_dirs = (Get-ChildItem -Path "$($msg_dir.FullName)\Image" -Directory)
    foreach ($month_dir in $month_dirs) {
        $file_cnt = 0
        foreach ($file in (Get-ChildItem -Path $month_dir.FullName -File)) {
            $formattedDate = $file.CreationTime.ToString("yyyyMMdd")
            $output_file_prefix = "$export_path\$month_dir\$formattedDate-聊天_$msg_dir_cnt-$file_cnt"
            $null = New-Item -Force -Path "$export_path\$month_dir" -Type Directory
            # Convert the file to a byte array
            $res = [XORDecryptor]::DecryptOneFile($file.FullName, $output_file_prefix)

            $output_file_path = $output_file_prefix + "." + $res.Ext
            $file_cnt++
            Write-Output "$($file.FullName),$output_file_path,$($res.Key)" >> $mapping_file_path
        }
    }
    $msg_dir_cnt++
}
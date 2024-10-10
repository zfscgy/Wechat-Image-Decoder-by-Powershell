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
    ΢��ͼƬ�ļ���ȡ���ߣ������ߣ�Free Engineer��zf6792@163.com
    �ù��߻����΢�������¼�ļ����С�Wechat Files����ͼƬ�ļ������ҽ���ת�Ƶ���ZF_�����ͼƬ���ļ��У�������-�¡��ķ�ʽ�洢���ļ�����ʾ΢�����ظ�ͼƬ��ʱ�䡣
    ʹ�øù��ߣ����Է������΢�������¼�е�ͼƬ����ʡ���Կռ䡣������ͼƬת�ƺ󣬿���ɾ��΢���ļ����ж�Ӧ�ġ�Image������MsgAttach���ļ��С�
    ������Ҳ�����ҵ���ɾ���������¼�е�ͼƬ��΢�����޷��ҵ�����
    ע������ͼƬ�����벢ת�ƣ�����ɾ�����������ļ��к�΢�ŵ������л����ͼƬ�޷����ص������������������
===============================================================
"


if (!(Test-Path -Path "./Image") -and !(Test-Path -Path "./MsgAttach")) {
    Write-Host "������δ��⵽΢���ļ��У��뽫�ýű�����΢���ļ��У�Wechat Files��������·��λ���ڡ�΢��-����-�ļ������鿴" -ForegroundColor 'RED'
    Exit
}

$export_path = "$((Get-Item .).FullName)\ZF_�����ͼƬ"
Write-Host "�����ļ���ַ��$export_path"
# New-Item $export_path -Type Directory


if (Test-Path -Path $export_path) {
    Write-Host "�����ļ���ַ�Ѿ����ڣ�" -ForegroundColor 'RED'
    Read-Host "����������������粻���������ֱ�ӹر�Powershell���� �� ��Ctrl + C�˳�"
}


Write-Host "
===================================
    ��ʼ����ͼƬ����...
===================================
"

$mapping_file_path = "$export_path\·����Ӧ��ϵ.txt"
$null = New-Item -Force -Path $mapping_file_path -Type File

Write-Host "���� 2022-06 ֮ǰ��ͼƬ����..."

$month_dirs = Get-ChildItem -Path ".\Image\" -Directory

# Iterate through each file
$month_dir_cnt = 0
foreach ($month_dir in $month_dirs) {
    Write-Progress -Id 0 -Activity "��ȡ2022-06֮ǰ������" -Status "$($month_dir_cnt * 100 / $month_dirs.Count)%" -PercentComplete ($month_dir_cnt  * 100 / $month_dirs.Count)

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

Write-Host "���� 2022-06 ֮���ͼƬ����..."

$msg_dirs = Get-ChildItem -Path ".\MsgAttach\" -Directory

$msg_dir_cnt = 0
foreach($msg_dir in $msg_dirs) {
    Write-Progress -Id 1 -Activity "��ȡ2022-06֮�������" -Status "$($msg_dir_cnt * 100 / $msg_dirs.Count)%" -PercentComplete ($msg_dir_cnt  * 100 / $msg_dirs.Count)
    if (!(Test-Path -Path "$($msg_dir.FullName)\Image")) {
        continue
    }
    $month_dirs = (Get-ChildItem -Path "$($msg_dir.FullName)\Image" -Directory)
    foreach ($month_dir in $month_dirs) {
        $file_cnt = 0
        foreach ($file in (Get-ChildItem -Path $month_dir.FullName -File)) {
            $formattedDate = $file.CreationTime.ToString("yyyyMMdd")
            $output_file_prefix = "$export_path\$month_dir\$formattedDate-����_$msg_dir_cnt-$file_cnt"
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
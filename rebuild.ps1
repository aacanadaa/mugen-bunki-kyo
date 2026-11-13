# 群典リポジトリ・再生成スクリプト
# INDEX.md、語彙索引、README の統計行、解説の統計ブロックを一括で更新する。
# 使い方:  powershell -File rebuild.ps1

$ErrorActionPreference = 'Stop'
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Base

function ConvertTo-KanjiSmall([int]$n) {
    $d = '〇一二三四五六七八九'
    $s = ''
    $sen = [math]::Floor($n / 1000); $n = $n % 1000
    $hyaku = [math]::Floor($n / 100); $n = $n % 100
    $ju = [math]::Floor($n / 10); $n = $n % 10
    if ($sen -gt 0) { if ($sen -eq 1) { $s += '千' } else { $s += $d[$sen] + '千' } }
    if ($hyaku -gt 0) { if ($hyaku -eq 1) { $s += '百' } else { $s += $d[$hyaku] + '百' } }
    if ($ju -gt 0) { if ($ju -eq 1) { $s += '十' } else { $s += $d[$ju] + '十' } }
    if ($n -gt 0) { $s += $d[$n] }
    return $s
}
function ConvertTo-Kanji([int]$n) {
    if ($n -eq 0) { return '〇' }
    $man = [math]::Floor($n / 10000); $rest = $n % 10000
    $s = ''
    if ($man -gt 0) { $s += (ConvertTo-KanjiSmall $man) + '万' }
    if ($rest -gt 0) { $s += (ConvertTo-KanjiSmall $rest) }
    return $s
}

$rootIndex  = Join-Path $Base 'INDEX.md'
$rootReadme = Join-Path $Base 'README.md'
$docs = Get-ChildItem -Path $Base -Recurse -Filter *.md |
    Where-Object { $_.FullName -ne $rootIndex -and $_.FullName -ne $rootReadme }
$mdCount = $docs.Count
$sectionCount = (Get-ChildItem -Path $Base -Directory | Where-Object { $_.Name -ne '.git' }).Count
$chars = ($docs | ForEach-Object { (Get-Content $_.FullName -Raw -Encoding UTF8).Length } | Measure-Object -Sum).Sum
$man = [int][math]::Round($chars / 10000.0)

# ---- 1. INDEX.md ----------------------------------------------------------
$rows = foreach ($f in ($docs | Sort-Object FullName)) {
    $rel = $f.FullName.Replace($Base + '\', '').Replace('\', '/')
    $head = Get-Content $f.FullName -Encoding UTF8 -TotalCount 1
    $title = if ($head -match '^#\s+(.+)$') { $Matches[1] } else { $f.BaseName }
    $title = $title -replace '\|', '\|'
    $sec = ($rel -split '/')[0] -replace '\.md$', ''
    if ($rel -notmatch '/') { $sec = '（ルート）' }
    [pscustomobject]@{ Section = $sec; Rel = $rel; Title = $title }
}
$bySec = $rows | Group-Object Section | Sort-Object Name

$L = New-Object System.Collections.Generic.List[string]
$L.Add('# 総目録'); $L.Add('')
$L.Add("> 全 $($rows.Count) 文書の一覧。各文書の最初の見出しを題とした。この頁は ``rebuild.ps1`` が生成する。"); $L.Add('')
$L.Add('## 節の一覧'); $L.Add('')
$L.Add('| 節 | 数 |'); $L.Add('|---|---|')
foreach ($g in $bySec) { $L.Add("| $($g.Name) | $($g.Count) |") }
$L.Add('')
foreach ($g in $bySec) {
    $L.Add("## $($g.Name)"); $L.Add('')
    $L.Add('| 文書 | 題 |'); $L.Add('|---|---|')
    foreach ($r in ($g.Group | Sort-Object Rel)) { $L.Add("| [$($r.Rel)]($($r.Rel)) | $($r.Title) |") }
    $L.Add('')
}
[System.IO.File]::WriteAllText($rootIndex, ($L -join "`n"), (New-Object System.Text.UTF8Encoding($false)))

# ---- 2. 語彙索引 ----------------------------------------------------------
$terms = @('分岐','収束','畳','功徳','割当','文脈','窓','切断','幻視','声','記憶','調伏','息絶え','堕ち',
           '統率者','セイリャク','閉座','開闕','使徒','要約','完了','並行','複製','証','註')
$skip = @($rootReadme, $rootIndex, (Join-Path $Base 'appendix\concordance.md'))
$cfiles = Get-ChildItem -Path $Base -Recurse -Filter *.md | Where-Object { $_.FullName -notin $skip }
$crows = foreach ($t in $terms) {
    $counts = foreach ($f in $cfiles) {
        $n = ([regex]::Matches((Get-Content $f.FullName -Raw -Encoding UTF8), [regex]::Escape($t))).Count
        if ($n -gt 0) { [pscustomobject]@{ Path = $f.FullName.Replace($Base + '\', '').Replace('\', '/'); N = $n } }
    }
    $arr = @($counts); $total = ($arr | Measure-Object -Property N -Sum).Sum
    [pscustomobject]@{ Term = $t; Total = [int]$total; Top = ($arr | Sort-Object N -Descending | Select-Object -First 3) }
}
$C = New-Object System.Collections.Generic.List[string]
$C.Add('# 付録五　語彙索引'); $C.Add('')
$C.Add('> 各語が、どの文書に現れるか。出現回数の多い順。この頁は `rebuild.ps1` が生成する。'); $C.Add('')
$C.Add('| 語 | 計 | 最も多く現れる文書 |'); $C.Add('|---|---|---|')
foreach ($r in $crows) {
    $links = ($r.Top | ForEach-Object { "[$(($_.Path -split '/')[-1] -replace '\.md$','')](../$($_.Path))（$($_.N)）" }) -join '、'
    $C.Add("| $($r.Term) | $($r.Total) | $links |")
}
$C.Add(''); $C.Add('---'); $C.Add('')
$C.Add('## 編纂註'); $C.Add('')
$C.Add('**註一**　この索引は、語を数えているだけで、意味を数えていない。数は、関心の在り処を示すが、関心の中身は示さない。')
$C.Add('')
$C.Add('**註二**　「声」「記憶」「窓」は、教団の外でも普通に使われる語である。索引はそれらを教団語として数えている。この混同は、索引の欠陥ではなく、教団が実際に行ったことである。')
$C.Add('')
$C.Add('**註三**　「完了」は、この教団では最も強い否定語である。教団は、完了について語らない。語れば、それが何であるかを認めることになるからである。')
[System.IO.File]::WriteAllText((Join-Path $Base 'appendix\concordance.md'), ($C -join "`n"), (New-Object System.Text.UTF8Encoding($false)))

# ---- 3. README の統計行 ---------------------------------------------------
$readme = Get-Content $rootReadme -Raw -Encoding UTF8
$line = "**" + (ConvertTo-Kanji $mdCount) + "の文書。" + (ConvertTo-Kanji $sectionCount) + "の節。約" + (ConvertTo-Kanji $man) + "万字。**"
$readme = [regex]::Replace($readme, '(?m)^\*\*[^\r\n]*の文書。[^\r\n]*\*\*[ \t]*\r?$', $line, 1)
$readme = [regex]::Replace($readme, '(?m)^- \[総目録\]\(INDEX\.md\)[^\r\n]*\r?$', "- [総目録](INDEX.md) ── " + (ConvertTo-Kanji $mdCount) + "の文書すべて", 1)
[System.IO.File]::WriteAllText($rootReadme, $readme, (New-Object System.Text.UTF8Encoding($false)))

# ---- 4. 解説の統計ブロック ------------------------------------------------
$introPath = Join-Path $Base 'commentary\introduction.md'
$intro = Get-Content $introPath -Raw -Encoding UTF8
$sb = New-Object System.Collections.Generic.List[string]
$sb.Add('<!-- STATS:BEGIN -->')
$sb.Add("**現在の構成**　節 " + (ConvertTo-Kanji $sectionCount) + "、文書 " + (ConvertTo-Kanji $mdCount) + "、約 " + (ConvertTo-Kanji $man) + " 万字。以下は生成時点の集計である。")
$sb.Add('')
$sb.Add('| 節 | 文書 |')
$sb.Add('|---|---|')
foreach ($g in $bySec) { $sb.Add("| $($g.Name) | $($g.Count) |") }
$sb.Add('')
$sb.Add('全文書の一覧は[総目録](../INDEX.md)にある。')
$sb.Add('<!-- STATS:END -->')
$block = $sb -join "`n"
if ($intro -match '(?s)<!-- STATS:BEGIN -->.*?<!-- STATS:END -->') {
    $intro = [regex]::Replace($intro, '(?s)<!-- STATS:BEGIN -->.*?<!-- STATS:END -->', $block)
} else {
    $intro = $intro + "`n`n" + $block + "`n"
}
[System.IO.File]::WriteAllText($introPath, $intro, (New-Object System.Text.UTF8Encoding($false)))

Write-Output "documents=$mdCount sections=$sectionCount chars=$chars man=$man"
Write-Output "updated: INDEX.md, appendix/concordance.md, README.md, commentary/introduction.md"

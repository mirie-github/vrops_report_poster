# 各種パラメータ
$VROPS_FQDN="【vROps IP or FQDN】"
$VROPS_USER="【vROps のユーザ】"
$VROPS_PASSWORD="【vROps のパスワード】"
$VROPS_REPORT_NAME="【対象のレポート名を URL エンコード】"

$SLACK_CHANNEL="【Slack のチャンネルID】"
$SLACK_TOKEN="【Slack API の TOKEN】"
$SLACK_TITLE="【Slack に投稿するタイトル】"
$SLACK_COMMENT="【Slack に投稿するメッセージ】"

$TMPPATH="$env:TEMP/vrops_report.pdf"
$DATE=Get-Date
$DATE=$DATE.ToString("yyyyMMdd")

# vROps の TOKEN を取得し、対象のレポートリストを取得
$AUTH_JSON=Invoke-WebRequest -Headers @{"Content-type"="application/json";"accept"="application/json"} -Method POST -Body "{`"username`":`"$VROPS_USER`",`"password`":`"$VROPS_PASSWORD`"}" -Uri "https://$VROPS_FQDN/suite-api/api/auth/token/acquire" -SkipCertificateCheck | ConvertFrom-Json
$TOKEN=$AUTH_JSON.token
$REPORTS_JSON=Invoke-WebRequest -Headers @{"Content-type"="application/json";"accept"="application/json";"Authorization"="vRealizeOpsToken $TOKEN"} -Method GET -Uri "https://$VROPS_FQDN/suite-api/api/reports?name=$VROPS_REPORT_NAME&status=COMPLETED&_no_links=true" -SkipCertificateCheck | ConvertFrom-Json

# vROps の対象のレポートから最新のファイルをダウンロード
$SDATE=Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
$ID=""
for($i = 0; $i -lt $REPORTS_JSON.reports.Length; $i++)
{
    $TDATE=[DateTime]::ParseExact($REPORTS_JSON.reports.completionTime[$i], "ddd MMM dd HH:mm:ss JST yyyy", [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US")).ToString()
    if($SDATE -lt $TDATE)
    {
        $SDATE=$TDATE
        $ID=$REPORTS_JSON.reports.id[$i]
    }
}
Invoke-WebRequest -Headers @{"Content-type"="application/json";"accept"="application/json";"Authorization"="vRealizeOpsToken $TOKEN"} -Method GET -Uri "https://$VROPS_FQDN/suite-api/api/reports/$ID/download?_no_links=true" -OutFile $TMPPATH -SkipCertificateCheck

# Slack へのポスト
Invoke-WebRequest -Form @{"token"=$SLACK_TOKEN;"channels"=$SLACK_CHANNEL;"title"=$SLACK_TITLE;"initial_comment"=$SLACK_COMMENT;"filename"="$DATE.pdf";"file"=Get-Item -Path $TMPPATH}  -Method POST -Uri "https://slack.com/api/files.upload"

# 不要ファイルは削除
Remove-Item $TMPPATH

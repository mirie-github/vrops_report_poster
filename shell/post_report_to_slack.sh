#!/bin/sh
# 各種パラメータ
VROPS_FQDN=【vROps IP or FQDN】
VROPS_USER=【vROps のユーザ】
VROPS_PASSWORD=【vROps のパスワード】
VROPS_REPORT_NAME=【対象のレポート名を URL エンコード】

SLACK_CHANNEL=【Slack のチャンネルID】
SLACK_TOKEN=【Slack API の TOKEN】
SLACK_TITLE="【Slack に投稿するタイトル】"
SLACK_COMMENT="【Slack に投稿するメッセージ】"

TMPPATH="/tmp/vrops_report.pdf"

# # vROps の TOKEN を取得し、対象のレポートリストを取得
TOKEN=`curl -X POST "https://$VROPS_FQDN/suite-api/api/auth/token/acquire" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \"username\" : \"$VROPS_USER\", \"password\" : \"$VROPS_PASSWORD\"}" -k | jq -r .token`
REPORTS=`curl -X GET "https://$VROPS_FQDN/suite-api/api/reports?name=$VROPS_REPORT_NAME&status=COMPLETED&_no_links=true" -H "accept: application/json" -H "Authorization: vRealizeOpsToken $TOKEN" -k`
LENGTH=`echo $REPORTS | jq -r "[.reports[]] | length"`

# vROps の対象のレポートから最新のファイルをダウンロード
if [ "$LENGTH" != "" ] ;
then
  i=0
  SDATE="19700101000000"
  while [ $i -lt $LENGTH ];
  do
    TMP=`echo $REPORTS | jq ".reports[$i].completionTime"`
    TDATE=`python -c "import datetime;print(datetime.datetime.strptime($TMP, \"%a %b %d %H:%M:%S JST %Y\").strftime(\"%Y%m%d%H%M%S\"))"`
    if [ $SDATE -lt $TDATE ] ;
    then
      SDATE=$TDATE
      ID=`echo $REPORTS | jq -r ".reports[$i].id"`
    fi
    i=`expr $i + 1`
  done
else
  exit 1
fi
curl -X GET "https://$VROPS_FQDN/suite-api/api/reports/$ID/download?_no_links=true" -H "accept: application/pdf" -H "Authorization: vRealizeOpsToken $TOKEN" -o $TMPPATH -k

# Slack へのポスト
curl -X POST "https://slack.com/api/files.upload" -F channels=$SLACK_CHANNEL -F token=$SLACK_TOKEN -F file=@$TMPPATH -F filename=`date +"%Y%m%d"`.pdf -F title=$SLACK_TITLE -F initial_comment=$SLACK_COMMENT

# 不要ファイルは削除
rm $TMPPATH

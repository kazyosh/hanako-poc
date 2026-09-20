# はなこさん実証実験用アプリ

## 音声切り替え候補

Settings/VoiceOptions.jsonに切り替え可能な音声候補が設定されています  
Google [Cloud Text-to-Speech](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja)の[対応言語一覧](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja#list_of_all_supported_languages)に利用可能な言語と音声が記載されているので、以下の例を参考に変更してください

例.    `日本語（日本）| プレミアム | ja-JP	ja-JP-Chirp3-HD-Achernar | 女性`
~~~json
...
    {
      "name": "ja-JP-Chirp3-HD-Achernar",
      "displayName": "はなこ(プレミアム)",
      "gender": "FEMALE"
    }
,...
~~~

|項目名|設定値|
|:-|:-|
|name|[Cloud Text-to-Speech](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja)の[対応言語一覧](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja#list_of_all_supported_languages)に記載されている音声名|
|displayName|はなこアプリの設定画面に表示する名称|
|gender|[Cloud Text-to-Speech](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja)の[対応言語一覧](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja#list_of_all_supported_languages)に記載されているSSMLの性別|
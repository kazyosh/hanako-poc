# はなこさん実証実験用アプリ

## 音声切り替え候補

Settings/VoiceOptions.jsonに音声切り替え候補が設定されているので、Google [Cloud Text-to-Speech](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja)の[対応言語一覧](https://docs.cloud.google.com/text-to-speech/docs/list-voices-and-types?hl=ja#list_of_all_supported_languages)から日本語対応の音声を参考にVoiceOptions.jsonを追加、または変更してください

例 日本語（日本）	プレミアム	ja-JP	ja-JP-Chirp3-HD-Achernar	女性
~~~json
...
    {
      "name": "ja-JP-Chirp3-HD-Achernar",
      "displayName": "はなこ(現実的な抑揚)",
      "gender": "FEMALE"
    }
,...
~~~

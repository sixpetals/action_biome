# Action Biome

Godot 4.6 で作る 2D サイドビューのアクションサンドボックス縦スライス。

仕様入力: [docs/SPEC.md](docs/SPEC.md)

## 起動

WSL/Linux 側では今回導入した Godot で起動できる。

```bash
/tmp/action_biome_godot/Godot_v4.6.3-stable_linux.x86_64 --path .
```

Windows 側 Godot が使える環境では次を実行する。

```powershell
& "C:\Program Files\Godot\Godot_v4.6.3-stable_win64_console.exe" --path "\\wsl.localhost\Ubuntu\home\test\projects\private\action_biome"
```

WSL から Windows Godot 実行は、この環境では `UtilBindVsockAnyPort` エラーで失敗したため未検証。

## 検証

```bash
/tmp/action_biome_godot/Godot_v4.6.3-stable_linux.x86_64 --headless --path . -s res://tests/smoke_test.gd
```

smoke test は、世界生成、プレイヤー初期化、敵スポーン、採掘、配置、部屋判定、クラフト、操縦室UI、死亡復帰、保存/ロードを確認する。

## 操作

- `A` / `D`: 移動
- `Space`: ジャンプ、長押しで可変ジャンプ
- `Shift`: ダッシュ
- 左クリック: 採掘、または攻撃
- 右クリック: 選択スロットのブロック/家具を配置
- `E`: 作業台、操縦室、ドア、セーブコアを使用
- `1`-`9`, `0`: スロット切り替え
- `F5`: 手動保存
- `F9`: セーブ削除なしの新規開始

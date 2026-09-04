# 项目开发与 Android 真机部署规则

## 项目事实

- 项目类型：Flutter Android 应用。
- Android Gradle 模块：`app`。
- 日常真机开发变体：`standardDebug`。
- applicationId：`com.photostorer.photo_storer`。
- Launcher Activity：`com.photostorer.photo_storer.MainActivity`。
- 本地数据：sqflite SQLite、SharedPreferences、应用内部照片和封面文件。
- 当前数据库升级通过 `lib/data/database/app_database.dart` 中的版本化迁移完成。

## Android 手机部署原则

每次完成需要真机测试的修改后，优先从项目根目录运行：

```text
deploy.bat
```

自动化环境可运行：

```text
deploy.bat --no-pause
```

部署必须使用保留数据的覆盖安装方式（当前脚本使用 `adb install -r`）。

严格禁止：

```text
adb uninstall
pm clear
删除应用数据目录
因为安装失败而自动卸载应用
```

出现 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` 或其他签名冲突时，必须停止部署并提示用户，不得通过卸载规避。

不要随意修改 `applicationId`，也不要随意更换或删除开发签名。当前 Debug 及现有 Release 配置使用默认 Debug 签名；本机实际 keystore 为：

```text
C:\Users\35226\.android\debug.keystore
```

## 数据库安全

升级 APP 不等于清空数据库。数据库 schema 变化时必须：

1. 提升数据库版本。
2. 编写保留现有数据的顺序 Migration。
3. 为迁移补充测试。

禁止引入 destructive migration、删除数据库后重建、清空用户表或删除应用内部照片来解决 schema 问题。若无法安全迁移，应停止并向用户说明风险。

## 无线调试

Android 11+ 首次无线配对或连接时运行：

```text
connect-phone.bat
```

手机端的首次配对确认和配对码必须由用户本人在 Android“无线调试”页面完成，不得绕过系统授权。

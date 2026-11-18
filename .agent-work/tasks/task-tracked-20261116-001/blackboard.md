# 黑板（Blackboard）——任务意图层记忆池

> 本文件是同任务所有会话的共享记忆：结论写这里，别只进 worklog。
> 新会话开工前先读本文件（GUI 会在首回合自动注入摘要）；完成子目标、
> 排除路径、踩坑之后，用 Edit 更新对应段落。保持精炼，过时内容删除。

## 当前目标（Current Goal）

对这个项目进行一些需求的跟进

## 已完成（Done）

- [x] 提取桌面《相册分类需求.doc》内容：13 条文字需求 + 1 张时间线页截图（截图已存 .agent-work/req_image.png，文本在 .agent-work/req_extract.txt）
- [x] 完成 13 条需求可行性分析并输出给用户评估（结论：全部可行，按 Bug修复/数据/功能/新功能 分组；需 DB migration 的有 #2 去重、#3 虚拟相册、#7 时间胶囊）
- [x] 修复 5 个 Bug（用户批准计划后实施，flutter analyze 0 error、31 测试全过）：
  - #1 时间线/图库切 tab 自动刷新（MainShell ValueNotifier 信号 + silentRefresh）+ 时间线下拉刷新
  - #2 导入去重：photos 加 content_hash 列（DB v10→11 迁移）、导入前 sha256 查重跳过、启动时存量回填、UI 提示"跳过 N 张重复"
  - #4 私密相册退后台立即重锁（app.dart 生命周期 paused/hidden 时 lockAll）
  - #5 MediaThumbnail 改 StatefulWidget 缓存 future，消除点选时全列表异步重载（卡顿根因）
  - #10 图库 Expanded 加 ValueKey，选择模式切换不再重建网格（回顶根因）
- [x] 交互优化 3 项完成（flutter analyze 0 error/warning、32 测试全过）：
  - #11 删刷新按钮：图库/相册详情右下角只剩导入按钮；相册详情页补了 RefreshIndicator + AlwaysScrollableScrollPhysics
  - #13 图库多选批量栏新增"移入"按钮 → 单选相册 → addCategories（多对多，照片仍在图库可见）
  - #12 图库智能相册行末尾加"按时间分组" ChoiceChip → 分组视图（按月 header + SliverGrid，与时间线同构）；controller.groupByTime 纯视图切换不重查
- [x] 虚拟相册 + 朋友圈个性化完成（分支 feature/virtual-album-and-persona，提交 b279c17；48 测试全过、analyze 0 error/warning）：
  - 虚拟相册 = 规则型智能相册（方向 A）：DB v12（themes.is_virtual/virtual_rules），规则=标签+时间范围+仅收藏，打开时实时查询；复用 ThemeDetailPage；首页创建表单内嵌规则编辑，详情页可改规则
  - 朋友圈个性化：AiPersona 四字段存 SharedPreferences，注入 system prompt；AI 设置页编辑 + "AI 帮我完善"；文案页显示应用状态
  - 用户已明确不做：#7 时间胶囊、#6 相似合并、#8 水印、#9 图片编辑；识图 API 独立排期
- [x] v1.1.0 发版完成：功能分支已合并回 main（--no-ff），版本号 1.1.0+2，标签 v1.1.0 指向 0f76c9d；release APK 产出 releases/photo_storer-v1.1.0-standard-release.apk（70MB，standard flavor）
- [x] 发版踩坑记录：① Flutter 要求 Gradle ≥8.14，wrapper 已升级；② services.gradle.org 直连下载卡死（.part 0 字节），用腾讯镜像手动下载 zip 放入 wrapper/dists 后解决；③ 项目有 flavor（standard/zero），`flutter build apk --release` 会在默认路径找不到 APK 而误报失败，实际产物在 build/app/outputs/flutter-apk/app-{flavor}-release.apk
- [ ] 待用户真机验证 v1.1.0；main 分支尚未推送到远端（public/main）

## 阻塞点（Blocked）

（暂无——被什么卡住、需要谁给什么、何时要）

## 交接说明（Handoff）

- DB 版本已升到 11（photos.content_hash 列 + idx_photos_content_hash 索引），迁移测试在 test/data_layer_test.dart
- 去重存的是**源文件** hash（_ensureFlutterCompatible 转换会改字节，存源 hash 才能二次导入命中）；存量数据启动时 fire-and-forget 回填（main.dart → PhotoImportService.backfillContentHashes）
- MainShell 的 tab 刷新信号是 ValueNotifier<int>，LibraryPage/TimelinePage 通过构造参数接收并 addListener；页面仍由 IndexedStack 保活
- setPassword 会自动解锁（创建者视角），测试私密相册时先 lockAll 再验证
- 剩余 8 条需求（#3 虚拟相册、#6 相似合并、#7 时间胶囊、#8 水印、#9 图片编辑、#11 删刷新按钮、#12 图库时间线合并、#13 图库移入相册）待用户定夺；#11 删按钮前需先补相册详情页下拉刷新

## 已排除的路（Dead Ends）

（暂无——试过不行的方案 + 一句话原因，防止后人重蹈）

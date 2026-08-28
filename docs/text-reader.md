# Spec: 纯文本阅读（TXT / Markdown / HTML）

## Objective

书库已经能存文件，但阅读页仍是固定的「白」样章。这一步让 **TXT、Markdown、HTML** 打开后显示原文件，目录来自章节切分，进度仍写回书库。

成功标准：

- 导入 `notes.txt` 后点开，正文是文件内容，而不是样章。
- Markdown 按标题切分，目录可跳转。
- EPUB/PDF/漫画仍明确提示尚未接入，不再假装能读。
- 演示书（本地空库种子）仍可用样章，避免空书架演示崩掉。
- 单文件最多解析前 1 MiB，按块切分，不把整本打成一个巨大 Widget。

## Assumptions

1. 第一版不做 EPUB/PDF 引擎（`index.md` Phase 1–2），先做最容易打通的纯文本。
2. 编码优先 UTF-8（含 BOM）和 UTF-16 BOM；不在这一步做 GBK。
3. Markdown 不当 HTML 渲染，只按 ATX 标题切章并显示原文。
4. HTML 去掉 script/style/标签后当文本读。
5. 无文件字节时（本地 SharedPreferences 重启后）提示找不到文件，不回退样章。

## Commands

```powershell
cd app
flutter test test/text_document_test.dart test/library_repository_test.dart test/widget_test.dart
flutter analyze
```

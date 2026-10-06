import assert from "node:assert/strict";
import test from "node:test";

import { copyFor, languageFromCode } from "./copy";

test("chinese locales use the chinese interface copy", () => {
  assert.equal(languageFromCode("zh"), "zh");
  assert.equal(languageFromCode("zh-Hans"), "zh");
  assert.equal(copyFor("zh").appTitle, "通用阅读器");
});

test("other locales use english interface copy", () => {
  assert.equal(languageFromCode("en"), "en");
  assert.equal(languageFromCode(null), "en");
  assert.equal(copyFor("en").scope, "This version reads TXT, Markdown, HTML, RTF, DOCX, ODT, EPUB, PDF, FB2, MOBI, AZW3, CHM, DJVU, and CBZ, CBT, CBR, or CB7 comics.");
  assert.equal(copyFor("en").nextPage, "Next page");
  assert.equal(copyFor("en").readingSettings, "Reading settings");
  assert.equal(copyFor("zh").readingSettings, "阅读设置");
  assert.equal(copyFor("en").notesTitle, "Notes");
  assert.equal(copyFor("zh").noNotes, "这本书还没有笔记。");
  assert.equal(copyFor("en").deleteNote, "Delete note");
  assert.equal(copyFor("en").pageZoom, "Page zoom");
  assert.equal(copyFor("zh").pageZoom, "页面缩放");
  assert.equal(copyFor("en").comicLayoutDouble, "Double");
  assert.equal(copyFor("zh").comicReadRtl, "从右到左");
  assert.equal(copyFor("en").addBookmark, "Add bookmark");
  assert.equal(copyFor("en").bookmarkAt(2, 3), "Chapter 2, page 3");
  assert.equal(copyFor("en").deleteFromLibrary, "Remove from library");
  assert.equal(copyFor("en").editBookIdentity, "Edit title");
  assert.equal(copyFor("zh").bookAuthorLabel, "作者");
  assert.equal(copyFor("en").saveAction, "Save");
  assert.equal(copyFor("zh").shelfSearch, "搜索书名、作者或格式");
  assert.equal(copyFor("en").noShelfHits, "No book matches.");
  assert.equal(copyFor("zh").readingProgress, "阅读进度");
  assert.equal(copyFor("en").readingPercent(50), "50%");
  assert.equal(copyFor("zh").shelfFavorites, "收藏");
  assert.equal(copyFor("en").noSectionBooks, "Nothing in this shelf.");
  assert.equal(copyFor("en").addToNamedCollection("Tonight"), 'Add to "Tonight"');
  assert.equal(copyFor("zh").sortTitle, "标题");
  assert.equal(copyFor("zh").formatReflow, "可重排");
  assert.equal(copyFor("en").formatFixed, "Fixed layout");
  assert.equal(copyFor("zh").comicPage, "漫画页面");
  assert.equal(copyFor("en").comicPage, "Comic page");
  assert.equal(copyFor("zh").previousSide, "左侧翻页");
  assert.equal(copyFor("en").nextSide, "Next side");
  assert.equal(copyFor("en").continueReading, "Continue reading");
  assert.equal(copyFor("en").saveSelection, "Save selection");
  assert.equal(copyFor("zh").cancelAction, "取消");
  assert.equal(
    copyFor("en").shelfUnreadable,
    "This shelf was saved by a newer version and cannot be opened.",
  );
  assert.equal(copyFor("zh").shelfFailed, "书架打不开。");
  assert.equal(copyFor("en").find, "Find");
  assert.equal(copyFor("zh").find, "查找");
  assert.equal(copyFor("en").importFromWebdav, "Import from WebDAV");
  assert.equal(copyFor("zh").webdavEmpty, "这个目录里没有能打开的书。");
  assert.equal(copyFor("en").webdavFailed, "Could not read books from WebDAV.");
  assert.equal(copyFor("en").pushToWebdav, "Push to WebDAV");
  assert.equal(copyFor("zh").webdavNothing, "没有需要推到远端的书。");
  assert.equal(copyFor("en").importFromS3, "Import from S3");
  assert.equal(copyFor("zh").s3Storage, "S3 兼容存储");
  assert.equal(copyFor("en").s3Failed, "Could not read books from S3.");
  assert.equal(copyFor("zh").s3Empty, "这个前缀里没有能打开的书。");
  assert.equal(copyFor("en").pushToS3, "Push to S3");
  assert.equal(copyFor("zh").s3Nothing, "没有需要推到 S3 的书。");
  assert.equal(copyFor("en").syncS3Reading, "Sync reading data with S3");
  assert.equal(copyFor("zh").syncWebDavReading, "同步 WebDAV 阅读状态");
  assert.equal(copyFor("en").readingSyncFailed, "Reading progress could not be synced.");
  assert.equal(copyFor("en").askThisPage, "Ask this page");
  assert.equal(copyFor("zh").sendExcerpt, "发送摘录");
  assert.equal(copyFor("en").askFailed, "This page could not be asked.");
  assert.equal(copyFor("en").conversationHistory, "Conversation");
  assert.equal(copyFor("zh").conversationUnavailable, "无法读取问答记录。");
  assert.equal(copyFor("en").saveAsNote, "Save as a note");
  assert.equal(copyFor("zh").noteSaved, "已保存为笔记。");
  assert.equal(copyFor("en").jumpToLocation("2 / 2"), "Go to 2 / 2");
  assert.equal(copyFor("zh").jumpToLocation("2 / 2"), "跳转到 2 / 2");
  assert.equal(copyFor("en").askThisBook, "Ask this book");
  assert.equal(copyFor("zh").askThisBook, "问这本书");
  assert.equal(copyFor("en").askBookHint, "Matching passages from this book will be sent, not the whole book.");
  assert.equal(copyFor("zh").askBookHint, "将发送这本书里的命中段落，不上整本书。");
  assert.equal(copyFor("zh").page(2, 8), "第 2 / 8 页");
});

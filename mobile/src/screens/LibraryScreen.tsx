import { createElement, useEffect, useState } from "react";
import { Image, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { coverUri } from "../cover";
import type { Copy } from "../copy";
import { confirmRemoval, type PendingRemoval } from "../shelf-removal";
import { collectionSection, documentMatchesSection, type ShelfCollection, type ShelfSections } from "../shelf-sections";
import { shelfByFormat, type ShelfFormatFilter } from "../shelf-format";
import { continueReading, shelfSort, type ShelfSort } from "../shelf-sort";
import { shelfSearch, type ShelfSearchNote } from "../shelf-search";
import type { BookNote } from "../note-store";
import type { ShelfBook } from "../shelf-store";

export type ShelfEntry = ShelfBook;

type Notice =
  | "corrupt"
  | "unavailable"
  | "unsupported"
  | "read-failed"
  | "shelf-unreadable"
  | "shelf-failed"
  | "webdav-failed"
  | "webdav-empty"
  | "webdav-nothing"
  | "webdav-push-failed"
  | "s3-failed"
  | "s3-empty"
  | "s3-nothing"
  | "s3-push-failed"
  | "reading-sync-failed";

function Cover({ bytes }: { bytes: Uint8Array | null }) {
  const uri = bytes ? coverUri(bytes) : null;
  if (uri == null) return null;
  if (Platform.OS === "web") {
    return createElement("img", {
      alt: "",
      src: uri,
      style: { height: 64, objectFit: "cover", width: 46 },
    });
  }
  return <Image accessible={false} resizeMode="cover" source={{ uri }} style={styles.cover} />;
}

function formatLabel(format: ShelfEntry["format"]): string {
  if (format === "markdown") return "MD";
  if (format === "html") return "HTML";
  if (format === "epub") return "EPUB";
  if (format === "pdf") return "PDF";
  if (format === "fb2") return "FB2";
  if (format === "rtf") return "RTF";
  if (format === "docx") return "DOCX";
  if (format === "odt") return "ODT";
  if (format === "mobi") return "MOBI";
  if (format === "azw3") return "AZW3";
  if (format === "chm") return "CHM";
  if (format === "djvu") return "DJVU";
  if (format === "cbz") return "CBZ";
  if (format === "cbt") return "CBT";
  if (format === "cbr") return "CBR";
  if (format === "cb7") return "CB7";
  return "TXT";
}

type Props = {
  copy: Copy;
  shelf: ShelfEntry[];
  ready: boolean;
  notice: Notice | null;
  onOpenFile: () => void;
  onOpenEntry: (id: string) => void;
  onRemove: (id: string) => void;
  onRename: (id: string, title: string, author: string) => void;
  onLoadNotes: (id: string) => Promise<BookNote[]>;
  sections: ShelfSections;
  onToggleFavorite: (id: string) => void;
  onCreateCollection: (name: string) => Promise<ShelfCollection | null>;
  onToggleCollection: (collectionId: string, id: string) => void;
  onDeleteCollection: (id: string) => void;
  onImportWebDav: (account: { baseUrl: string; username: string; password: string }) => Promise<void>;
  onPushWebDav: (account: { baseUrl: string; username: string; password: string }) => Promise<void>;
  onSyncWebDavReading: (account: { baseUrl: string; username: string; password: string }) => Promise<void>;
  onImportS3: (account: {
    endpoint: string;
    region: string;
    bucket: string;
    prefix: string;
    accessKey: string;
    secretKey: string;
  }) => Promise<void>;
  onPushS3: (account: {
    endpoint: string;
    region: string;
    bucket: string;
    prefix: string;
    accessKey: string;
    secretKey: string;
  }) => Promise<void>;
  onSyncS3Reading: (account: {
    endpoint: string;
    region: string;
    bucket: string;
    prefix: string;
    accessKey: string;
    secretKey: string;
  }) => Promise<void>;
};

export function LibraryScreen({
  copy,
  shelf,
  ready,
  notice,
  onOpenFile,
  onOpenEntry,
  onRemove,
  onRename,
  onLoadNotes,
  sections,
  onToggleFavorite,
  onCreateCollection,
  onToggleCollection,
  onDeleteCollection,
  onImportWebDav,
  onPushWebDav,
  onSyncWebDavReading,
  onImportS3,
  onPushS3,
  onSyncS3Reading,
}: Props) {
  const [baseUrl, setBaseUrl] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [s3Open, setS3Open] = useState(false);
  const [endpoint, setEndpoint] = useState("");
  const [region, setRegion] = useState("");
  const [bucket, setBucket] = useState("");
  const [prefix, setPrefix] = useState("");
  const [accessKey, setAccessKey] = useState("");
  const [secretKey, setSecretKey] = useState("");
  const [importing, setImporting] = useState(false);
  const [pendingRemoval, setPendingRemoval] = useState<PendingRemoval | null>(null);
  const [pendingIdentity, setPendingIdentity] = useState<{ id: string; title: string; author: string } | null>(null);
  const [draftTitle, setDraftTitle] = useState("");
  const [draftAuthor, setDraftAuthor] = useState("");
  const [shelfQuery, setShelfQuery] = useState("");
  const [section, setSection] = useState("all");
  const [sortMode, setSortMode] = useState<ShelfSort>("shelf");
  const [formatFilter, setFormatFilter] = useState<ShelfFormatFilter>("all");
  const [creatingCollection, setCreatingCollection] = useState(false);
  const [collectionName, setCollectionName] = useState("");
  const [collectionTarget, setCollectionTarget] = useState<string | null>(null);
  const [notesById, setNotesById] = useState<Record<string, ShelfSearchNote[]>>({});
  const noticeText =
    notice === "corrupt"
      ? copy.corrupt
      : notice === "unavailable"
        ? copy.unavailable
        : notice === "unsupported"
          ? copy.unsupported
          : notice === "read-failed"
            ? copy.readFailed
            : notice === "shelf-unreadable"
              ? copy.shelfUnreadable
              : notice === "shelf-failed"
                ? copy.shelfFailed
                : notice === "webdav-failed"
                  ? copy.webdavFailed
                  : notice === "webdav-empty"
                    ? copy.webdavEmpty
                    : notice === "webdav-nothing"
                      ? copy.webdavNothing
                      : notice === "webdav-push-failed"
                        ? copy.webdavPushFailed
                        : notice === "s3-failed"
                          ? copy.s3Failed
                          : notice === "s3-empty"
                          ? copy.s3Empty
                          : notice === "s3-nothing"
                            ? copy.s3Nothing
                            : notice === "s3-push-failed"
                          ? copy.s3PushFailed
                          : notice === "reading-sync-failed"
                            ? copy.readingSyncFailed
                            : null;
  const showEmpty = ready && shelf.length === 0 && notice !== "shelf-unreadable" && notice !== "shelf-failed";
  const canImport = ready && notice !== "shelf-unreadable" && notice !== "shelf-failed" && !importing;
  const searched = shelfSearch(shelf, shelfQuery, (id) => notesById[id] ?? [], formatLabel);
  const matched = searched.filter((entry) =>
    documentMatchesSection({ section, documentId: entry.id, progress: entry.progress, shelves: sections }),
  );
  const visible = shelfSort(shelfByFormat(matched, formatFilter), sortMode);
  const nextBook = section === "all" ? continueReading(shelf) : null;
  const noSearchHits = shelfQuery.trim().length > 0 && searched.length === 0 && shelf.length > 0;
  const openCollection = sections.collections.find((collection) => collectionSection(collection.id) === section) ?? null;
  const collectionBook = shelf.find((entry) => entry.id === collectionTarget) ?? null;
  useEffect(() => {
    if (!section.startsWith("collection:")) return;
    const id = section.slice("collection:".length);
    if (!sections.collections.some((collection) => collection.id === id)) setSection("all");
  }, [section, sections]);
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const next: Record<string, ShelfSearchNote[]> = {};
      for (const entry of shelf) {
        try {
          next[entry.id] = await onLoadNotes(entry.id);
        } catch {
          next[entry.id] = [];
        }
      }
      if (!cancelled) setNotesById(next);
    })();
    return () => {
      cancelled = true;
    };
  }, [onLoadNotes, shelf]);

  return (
    <ScrollView contentContainerStyle={styles.screenContent} style={styles.screen}>
      <Text style={styles.title}>{copy.appTitle}</Text>
      <Text style={styles.scope}>{copy.scope}</Text>
      <Pressable accessibilityRole="button" onPress={onOpenFile} style={styles.open}>
        <Text style={styles.openLabel}>{copy.openFile}</Text>
      </Pressable>
      <TextInput
        accessibilityLabel={copy.webdavUrl}
        autoCapitalize="none"
        autoCorrect={false}
        onChangeText={setBaseUrl}
        placeholder={copy.webdavUrl}
        placeholderTextColor="#8A7358"
        style={styles.field}
        value={baseUrl}
      />
      <TextInput
        accessibilityLabel={copy.webdavUser}
        autoCapitalize="none"
        autoCorrect={false}
        onChangeText={setUsername}
        placeholder={copy.webdavUser}
        placeholderTextColor="#8A7358"
        style={styles.field}
        value={username}
      />
      <TextInput
        accessibilityLabel={copy.webdavPassword}
        autoCapitalize="none"
        autoCorrect={false}
        onChangeText={setPassword}
        placeholder={copy.webdavPassword}
        placeholderTextColor="#8A7358"
        secureTextEntry
        style={styles.field}
        value={password}
      />
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ disabled: !canImport }}
        disabled={!canImport}
        onPress={() => {
          if (!canImport) return;
          setImporting(true);
          void onImportWebDav({ baseUrl, username, password }).finally(() => {
            setImporting(false);
          });
        }}
        style={[styles.open, styles.importButton, !canImport && styles.openDisabled]}
      >
        <Text style={styles.openLabel}>{copy.importFromWebdav}</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ disabled: !canImport }}
        disabled={!canImport}
        onPress={() => {
          if (!canImport) return;
          setImporting(true);
          void onPushWebDav({ baseUrl, username, password }).finally(() => {
            setImporting(false);
          });
        }}
        style={[styles.open, styles.importButton, !canImport && styles.openDisabled]}
      >
        <Text style={styles.openLabel}>{copy.pushToWebdav}</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ disabled: !canImport }}
        disabled={!canImport}
        onPress={() => {
          if (!canImport) return;
          setImporting(true);
          void onSyncWebDavReading({ baseUrl, username, password }).finally(() => {
            setImporting(false);
          });
        }}
        style={[styles.open, styles.importButton, !canImport && styles.openDisabled]}
      >
        <Text style={styles.openLabel}>{copy.syncWebDavReading}</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        onPress={() => setS3Open((open) => !open)}
        style={[styles.open, styles.importButton]}
      >
        <Text style={styles.openLabel}>{copy.s3Storage}</Text>
      </Pressable>
      {s3Open ? (
        <View>
          <TextInput
            accessibilityLabel={copy.s3Endpoint}
            autoCapitalize="none"
            autoCorrect={false}
            onChangeText={setEndpoint}
            placeholder={copy.s3Endpoint}
            placeholderTextColor="#8A7358"
            style={styles.field}
            value={endpoint}
          />
          <TextInput
            accessibilityLabel={copy.s3Region}
            autoCapitalize="none"
            autoCorrect={false}
            onChangeText={setRegion}
            placeholder={copy.s3Region}
            placeholderTextColor="#8A7358"
            style={styles.field}
            value={region}
          />
          <TextInput
            accessibilityLabel={copy.s3Bucket}
            autoCapitalize="none"
            autoCorrect={false}
            onChangeText={setBucket}
            placeholder={copy.s3Bucket}
            placeholderTextColor="#8A7358"
            style={styles.field}
            value={bucket}
          />
          <TextInput
            accessibilityLabel={copy.s3Prefix}
            autoCapitalize="none"
            autoCorrect={false}
            onChangeText={setPrefix}
            placeholder={copy.s3Prefix}
            placeholderTextColor="#8A7358"
            style={styles.field}
            value={prefix}
          />
          <TextInput
            accessibilityLabel={copy.s3AccessKey}
            autoCapitalize="none"
            autoCorrect={false}
            onChangeText={setAccessKey}
            placeholder={copy.s3AccessKey}
            placeholderTextColor="#8A7358"
            style={styles.field}
            value={accessKey}
          />
          <TextInput
            accessibilityLabel={copy.s3SecretKey}
            autoCapitalize="none"
            autoCorrect={false}
            onChangeText={setSecretKey}
            placeholder={copy.s3SecretKey}
            placeholderTextColor="#8A7358"
            secureTextEntry
            style={styles.field}
            value={secretKey}
          />
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ disabled: !canImport }}
            disabled={!canImport}
            onPress={() => {
              if (!canImport) return;
              setImporting(true);
              void onImportS3({ endpoint, region, bucket, prefix, accessKey, secretKey }).finally(() => {
                setImporting(false);
              });
            }}
            style={[styles.open, styles.importButton, !canImport && styles.openDisabled]}
          >
            <Text style={styles.openLabel}>{copy.importFromS3}</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ disabled: !canImport }}
            disabled={!canImport}
            onPress={() => {
              if (!canImport) return;
              setImporting(true);
              void onPushS3({ endpoint, region, bucket, prefix, accessKey, secretKey }).finally(() => {
                setImporting(false);
              });
            }}
            style={[styles.open, styles.importButton, !canImport && styles.openDisabled]}
          >
            <Text style={styles.openLabel}>{copy.pushToS3}</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ disabled: !canImport }}
            disabled={!canImport}
            onPress={() => {
              if (!canImport) return;
              setImporting(true);
              void onSyncS3Reading({ endpoint, region, bucket, prefix, accessKey, secretKey }).finally(() => {
                setImporting(false);
              });
            }}
            style={[styles.open, styles.importButton, !canImport && styles.openDisabled]}
          >
            <Text style={styles.openLabel}>{copy.syncS3Reading}</Text>
          </Pressable>
        </View>
      ) : null}
      {noticeText ? <Text style={styles.notice}>{noticeText}</Text> : null}
      {pendingRemoval ? (
        <View style={styles.confirm}>
          <Text style={styles.confirmText}>{copy.deleteBookConfirm(pendingRemoval.title)}</Text>
          <View style={styles.confirmActions}>
            <Pressable accessibilityRole="button" onPress={() => setPendingRemoval(null)} style={styles.confirmButton}>
              <Text style={styles.confirmCancel}>{copy.cancelAction}</Text>
            </Pressable>
            <Pressable
              accessibilityRole="button"
              onPress={() => {
                const id = confirmRemoval(pendingRemoval, "delete");
                setPendingRemoval(null);
                if (id) onRemove(id);
              }}
              style={styles.confirmButton}
            >
              <Text style={styles.confirmDelete}>{copy.confirmDelete}</Text>
            </Pressable>
          </View>
        </View>
      ) : null}
      {pendingIdentity ? (
        <View style={styles.confirm}>
          <Text style={styles.confirmText}>{copy.editBookIdentity}</Text>
          <TextInput
            accessibilityLabel={copy.bookTitleLabel}
            maxLength={200}
            onChangeText={setDraftTitle}
            style={styles.field}
            value={draftTitle}
          />
          <TextInput
            accessibilityLabel={copy.bookAuthorLabel}
            maxLength={200}
            onChangeText={setDraftAuthor}
            style={styles.field}
            value={draftAuthor}
          />
          <View style={styles.confirmActions}>
            <Pressable accessibilityRole="button" onPress={() => setPendingIdentity(null)} style={styles.confirmButton}>
              <Text style={styles.confirmCancel}>{copy.cancelAction}</Text>
            </Pressable>
            <Pressable
              accessibilityRole="button"
              onPress={() => {
                const editing = pendingIdentity;
                setPendingIdentity(null);
                if (editing) onRename(editing.id, draftTitle, draftAuthor);
              }}
              style={styles.confirmButton}
            >
              <Text style={styles.confirmCancel}>{copy.saveAction}</Text>
            </Pressable>
          </View>
        </View>
      ) : null}
      {shelf.length > 0 ? (
        <TextInput
          accessibilityLabel={copy.shelfSearch}
          autoCapitalize="none"
          autoCorrect={false}
          onChangeText={(value) => {
            setShelfQuery(value);
            setPendingRemoval(null);
            setPendingIdentity(null);
            setCreatingCollection(false);
            setCollectionTarget(null);
          }}
          placeholder={copy.shelfSearch}
          placeholderTextColor="#8A7358"
          style={styles.field}
          value={shelfQuery}
        />
      ) : null}
      {shelf.length > 0 ? (
        <View style={styles.sections}>
          {[
            ["all", copy.shelfAll],
            ["reading", copy.shelfReading],
            ["favorites", copy.shelfFavorites],
          ].map(([id, label]) => (
            <Pressable
              accessibilityRole="button"
              key={id}
              onPress={() => {
                setSection(id ?? "all");
                setPendingRemoval(null);
                setPendingIdentity(null);
                setCreatingCollection(false);
                setCollectionTarget(null);
              }}
              style={styles.sectionChip}
            >
              <Text style={styles.confirmCancel}>{label}</Text>
            </Pressable>
          ))}
          {sections.collections.map((collection) => (
            <Pressable
              accessibilityRole="button"
              key={collection.id}
              onPress={() => {
                setSection(collectionSection(collection.id));
                setPendingRemoval(null);
                setPendingIdentity(null);
                setCreatingCollection(false);
                setCollectionTarget(null);
              }}
              style={styles.sectionChip}
            >
              <Text style={styles.confirmCancel}>{collection.name}</Text>
            </Pressable>
          ))}
          <Pressable
            accessibilityRole="button"
            onPress={() => {
              setCreatingCollection(true);
              setCollectionName("");
              setPendingRemoval(null);
              setPendingIdentity(null);
              setCollectionTarget(null);
            }}
            style={styles.sectionChip}
          >
            <Text style={styles.confirmCancel}>{copy.newCollection}</Text>
          </Pressable>
        </View>
      ) : null}
      {shelf.length > 0 ? (
        <View style={styles.sections}>
          {(
            [
              ["all", copy.formatAll],
              ["reflow", copy.formatReflow],
              ["fixedPage", copy.formatFixed],
              ["comic", copy.formatComic],
            ] as const
          ).map(([id, label]) => (
            <Pressable
              accessibilityRole="button"
              key={id}
              onPress={() => {
                setFormatFilter(id);
                setPendingRemoval(null);
                setPendingIdentity(null);
                setCreatingCollection(false);
                setCollectionTarget(null);
              }}
              style={styles.sectionChip}
            >
              <Text style={styles.confirmCancel}>{label}</Text>
            </Pressable>
          ))}
        </View>
      ) : null}
      {shelf.length > 0 ? (
        <View style={styles.sections}>
          {(
            [
              ["shelf", copy.shelfOrder],
              ["recent", copy.sortRecent],
              ["title", copy.sortTitle],
              ["progress", copy.sortProgress],
            ] as const
          ).map(([id, label]) => (
            <Pressable
              accessibilityRole="button"
              key={id}
              onPress={() => {
                setSortMode(id);
                setPendingRemoval(null);
                setPendingIdentity(null);
                setCreatingCollection(false);
                setCollectionTarget(null);
              }}
              style={styles.sectionChip}
            >
              <Text style={styles.confirmCancel}>{label}</Text>
            </Pressable>
          ))}
        </View>
      ) : null}
      {nextBook ? (
        <Pressable
          accessibilityLabel={`${copy.continueReading}: ${nextBook.title} ${formatLabel(nextBook.format)}`}
          accessibilityRole="button"
          onPress={() => onOpenEntry(nextBook.id)}
          style={styles.sectionChip}
        >
          <Text style={styles.confirmCancel}>{copy.continueReading}</Text>
        </Pressable>
      ) : null}
      {creatingCollection ? (
        <View style={styles.confirm}>
          <Text style={styles.confirmText}>{copy.newCollection}</Text>
          <TextInput
            accessibilityLabel={copy.collectionNameHint}
            maxLength={40}
            onChangeText={setCollectionName}
            style={styles.field}
            value={collectionName}
          />
          <View style={styles.confirmActions}>
            <Pressable accessibilityRole="button" onPress={() => setCreatingCollection(false)} style={styles.confirmButton}>
              <Text style={styles.confirmCancel}>{copy.cancelAction}</Text>
            </Pressable>
            <Pressable
              accessibilityRole="button"
              onPress={() => {
                const name = collectionName;
                setCreatingCollection(false);
                void onCreateCollection(name).then((created) => {
                  if (created) setSection(collectionSection(created.id));
                });
              }}
              style={styles.confirmButton}
            >
              <Text style={styles.confirmCancel}>{copy.createCollection}</Text>
            </Pressable>
          </View>
        </View>
      ) : null}
      {openCollection ? (
        <Pressable
          accessibilityRole="button"
          onPress={() => {
            setCollectionTarget(null);
            onDeleteCollection(openCollection.id);
          }}
          style={styles.remove}
        >
          <Text style={styles.removeLabel}>{copy.deleteCollection}</Text>
        </Pressable>
      ) : null}
      {collectionBook ? (
        <View style={styles.confirm}>
          <Text style={styles.confirmText}>{copy.collections}</Text>
          {sections.collections.length === 0 ? <Text style={styles.empty}>{copy.noCollections}</Text> : null}
          {sections.collections.map((collection) => {
            const member = collection.documentIds.includes(collectionBook.id);
            const label = member
              ? copy.removeFromNamedCollection(collection.name)
              : copy.addToNamedCollection(collection.name);
            return (
              <Pressable
                accessibilityLabel={`${label}: ${collectionBook.title} ${formatLabel(collectionBook.format)}`}
                accessibilityRole="button"
                key={collection.id}
                onPress={() => onToggleCollection(collection.id, collectionBook.id)}
                style={styles.confirmButton}
              >
                <Text style={styles.confirmCancel}>{label}</Text>
              </Pressable>
            );
          })}
          <Pressable accessibilityRole="button" onPress={() => setCollectionTarget(null)} style={styles.confirmButton}>
            <Text style={styles.confirmCancel}>{copy.close}</Text>
          </Pressable>
        </View>
      ) : null}
      {showEmpty ? (
        <Text style={styles.empty}>{copy.emptyShelf}</Text>
      ) : noSearchHits ? (
        <Text style={styles.empty}>{copy.noShelfHits}</Text>
      ) : visible.length === 0 && shelf.length > 0 ? (
        <Text style={styles.empty}>{copy.noSectionBooks}</Text>
      ) : shelf.length === 0 ? null : (
        <View style={styles.list}>
          {visible.map((entry) => (
            <View key={entry.id} style={styles.row}>
              <Pressable
                accessibilityRole="button"
                onPress={() => onOpenEntry(entry.id)}
                style={styles.rowMain}
              >
                <Cover bytes={entry.cover} />
                <View style={styles.rowText}>
                  <Text style={styles.rowTitle}>{entry.title}</Text>
                  {entry.author.length > 0 ? <Text style={styles.rowAuthor}>{entry.author}</Text> : null}
                  <Text style={styles.rowFormat}>{formatLabel(entry.format)}</Text>
                </View>
              </Pressable>
              <Pressable
                accessibilityLabel={`${sections.favoriteIds.includes(entry.id) ? copy.removeFromFavorites : copy.addToFavorites}: ${entry.title} ${formatLabel(entry.format)}`}
                accessibilityRole="button"
                onPress={() => onToggleFavorite(entry.id)}
                style={styles.remove}
              >
                <Text style={styles.confirmCancel}>
                  {sections.favoriteIds.includes(entry.id) ? copy.removeFromFavorites : copy.addToFavorites}
                </Text>
              </Pressable>
              <Pressable
                accessibilityLabel={`${copy.collections}: ${entry.title} ${formatLabel(entry.format)}`}
                accessibilityRole="button"
                onPress={() => {
                  setPendingRemoval(null);
                  setPendingIdentity(null);
                  setCreatingCollection(false);
                  setCollectionTarget(entry.id);
                }}
                style={styles.remove}
              >
                <Text style={styles.confirmCancel}>{copy.collections}</Text>
              </Pressable>
              <Pressable
                accessibilityLabel={`${copy.editBookIdentity}: ${entry.title} ${formatLabel(entry.format)}`}
                accessibilityRole="button"
                onPress={() => {
                  setPendingRemoval(null);
                  setPendingIdentity({ id: entry.id, title: entry.title, author: entry.author });
                  setDraftTitle(entry.title);
                  setDraftAuthor(entry.author);
                }}
                style={styles.remove}
              >
                <Text style={styles.confirmCancel}>{copy.editBookIdentity}</Text>
              </Pressable>
              <Pressable
                accessibilityLabel={`${copy.deleteFromLibrary}: ${entry.title} ${formatLabel(entry.format)}`}
                accessibilityRole="button"
                onPress={() => {
                  setPendingIdentity(null);
                  setPendingRemoval({ id: entry.id, title: entry.title });
                }}
                style={styles.remove}
              >
                <Text style={styles.removeLabel}>{copy.deleteFromLibrary}</Text>
              </Pressable>
            </View>
          ))}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#F7F4EE",
  },
  screenContent: {
    paddingHorizontal: 24,
    paddingTop: 28,
    paddingBottom: 32,
  },
  title: {
    color: "#1C2423",
    fontSize: 28,
    fontWeight: "600",
  },
  scope: {
    color: "#5C6563",
    fontSize: 16,
    lineHeight: 24,
    marginTop: 8,
  },
  open: {
    alignSelf: "flex-start",
    backgroundColor: "#2F5B57",
    borderRadius: 8,
    marginTop: 24,
    paddingHorizontal: 18,
    paddingVertical: 12,
  },
  openLabel: {
    color: "#F7F4EE",
    fontSize: 16,
    fontWeight: "600",
  },
  field: {
    borderColor: "#DDD6C8",
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    color: "#1C2423",
    fontSize: 16,
    marginTop: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  importButton: {
    marginTop: 12,
  },
  openDisabled: {
    opacity: 0.45,
  },
  notice: {
    color: "#8A3D32",
    fontSize: 16,
    lineHeight: 24,
    marginTop: 16,
  },
  empty: {
    color: "#5C6563",
    fontSize: 16,
    marginTop: 28,
  },
  list: {
    paddingTop: 8,
  },
  sections: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
    marginTop: 16,
  },
  sectionChip: {
    paddingVertical: 8,
  },
  row: {
    alignItems: "center",
    borderTopColor: "#DDD6C8",
    borderTopWidth: StyleSheet.hairlineWidth,
    flexDirection: "row",
    gap: 14,
    paddingVertical: 12,
  },
  rowMain: {
    alignItems: "center",
    flex: 1,
    flexDirection: "row",
    gap: 14,
  },
  remove: {
    paddingVertical: 8,
  },
  removeLabel: {
    color: "#8A3D32",
    fontSize: 14,
  },
  confirm: {
    backgroundColor: "#F7F4EE",
    gap: 8,
    marginTop: 16,
    padding: 12,
  },
  confirmText: {
    color: "#1C2423",
    fontSize: 16,
  },
  confirmActions: {
    flexDirection: "row",
    gap: 16,
  },
  confirmButton: {
    paddingVertical: 8,
  },
  confirmCancel: {
    color: "#2F5B57",
    fontSize: 16,
  },
  confirmDelete: {
    color: "#8A3D32",
    fontSize: 16,
  },
  cover: {
    height: 64,
    width: 46,
  },
  rowText: {
    flex: 1,
  },
  rowTitle: {
    color: "#1C2423",
    fontSize: 18,
  },
  rowAuthor: {
    color: "#5C6563",
    fontSize: 14,
    marginTop: 2,
  },
  rowFormat: {
    color: "#8A7358",
    fontSize: 12,
    letterSpacing: 0.6,
    marginTop: 4,
  },
});

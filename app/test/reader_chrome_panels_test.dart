import 'package:app/core/reader_chrome_panels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderChromePanels', () {
    test('default state has all panels closed', () {
      const panels = ReaderChromePanels();
      expect(panels.toc, false);
      expect(panels.bookmarks, false);
      expect(panels.showNotes, false);
      expect(panels.showSearch, false);
      expect(panels.anyOpen, false);
    });

    test('anyOpen is true when any single panel is open', () {
      expect(const ReaderChromePanels(toc: true).anyOpen, true);
      expect(const ReaderChromePanels(bookmarks: true).anyOpen, true);
      expect(const ReaderChromePanels(showNotes: true).anyOpen, true);
      expect(const ReaderChromePanels(showSearch: true).anyOpen, true);
    });

    test('toggle returns a new instance with the panel flipped', () {
      const initial = ReaderChromePanels();
      expect(initial.toggle(PanelKind.toc), const ReaderChromePanels(toc: true));
      expect(initial.toggle(PanelKind.bookmarks),
          const ReaderChromePanels(bookmarks: true));
      expect(initial.toggle(PanelKind.notes),
          const ReaderChromePanels(showNotes: true));
      expect(initial.toggle(PanelKind.search),
          const ReaderChromePanels(showSearch: true));
    });

    test('toggle is reversible', () {
      const initial = ReaderChromePanels();
      final toggled = initial.toggle(PanelKind.toc);
      expect(toggled.toggle(PanelKind.toc), initial);
    });

    test('closeAll clears every panel', () {
      const allOpen = ReaderChromePanels(
        toc: true,
        bookmarks: true,
        showNotes: true,
        showSearch: true,
      );
      expect(allOpen.closeAll(), const ReaderChromePanels());
      expect(allOpen.closeAll().anyOpen, false);
    });

    test('toggle on one panel leaves sibling panels untouched', () {
      const panels = ReaderChromePanels(bookmarks: true, showNotes: true);
      final after = panels.toggle(PanelKind.toc);
      expect(after.toc, true);
      expect(after.bookmarks, true);
      expect(after.showNotes, true);
      expect(after.showSearch, false);
    });

    test('toggling the same panel twice is a no-op', () {
      const panels = ReaderChromePanels(bookmarks: true);
      final t = panels.toggle(PanelKind.toc).toggle(PanelKind.toc);
      expect(t, panels);
    });

    test(
      'toggling search closes it regardless of other panels',
      () {
        const panels = ReaderChromePanels(
          toc: true,
          bookmarks: true,
          showNotes: true,
          showSearch: true,
        );
        final closed = panels.toggle(PanelKind.search);
        expect(closed.toc, true);
        expect(closed.bookmarks, true);
        expect(closed.showNotes, true);
        expect(closed.showSearch, false);
      },
    );

    test('anyOpen is true when several panels are open', () {
      const panels = ReaderChromePanels(toc: true, showNotes: true);
      expect(panels.anyOpen, true);
    });

    test('equality compares all four flags', () {
      const a = ReaderChromePanels(toc: true, bookmarks: true);
      const b = ReaderChromePanels(toc: true, bookmarks: true);
      const c = ReaderChromePanels(toc: true);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('equality across identical states has matching hashCode', () {
      const a = ReaderChromePanels(toc: true, showSearch: true);
      const b = ReaderChromePanels(toc: true, showSearch: true);
      expect(a.hashCode, b.hashCode);
    });

    test('toggle returns a different instance', () {
      const panels = ReaderChromePanels();
      expect(
        identical(panels.toggle(PanelKind.toc), panels),
        false,
      );
    });

    test('enum PanelKind has exactly four values', () {
      expect(PanelKind.values, hasLength(4));
      expect(
        PanelKind.values.toSet(),
        {PanelKind.toc, PanelKind.bookmarks, PanelKind.notes, PanelKind.search},
      );
    });
  });
}

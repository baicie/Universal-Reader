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
  });
}

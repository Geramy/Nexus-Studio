// Tests that templated web (Next.js) WORK_TEMPLATE.md ownership tables parse
// into per-task file scopes, so web workers get the same "write only here"
// steering the Flutter bullet format provides. Regression for the task-90
// block where an empty scope let the worker drift to /tmp and submit a noop.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/orchestration/project_orchestrator.dart';

const String registryTemplate = '''
# WORK TEMPLATE — House Sales Website

## Task Registry

| #id | Milestone | Title | Dependencies | Primary Files (task-owned) | Shared Contracts Consumed |
|-----|-----------|-------|--------------|----------------------------|---------------------------|
| #87 | 1 | Sticky top panel with search & filters | — | `components/SearchPanel.tsx` | `lib/types.ts` (SearchFilters), `lib/repository.ts` (HouseRepository) |
| #88 | 1 | Price filter | #87 | `components/SearchPanel.tsx` (extend) | `lib/types.ts` (SearchFilters.minPrice, maxPrice) |
| #89 | 1 | House listing panels + detail page + seed data | — | `app/page.tsx`, `app/houses/[id]/page.tsx`, `components/HouseCard.tsx`, `lib/seedData.ts` | `lib/types.ts` (House, Room), `lib/repository.ts` (HouseRepository) |
| #90 | 1 | Expandable room list + pre-filled contact box | #89 | `components/RoomList.tsx`, `components/ContactBox.tsx` | `lib/types.ts` (Room, House) |
| #91 | 1 | Main photos with priority cover photo | #89 | `components/HousePhotos.tsx` | `lib/types.ts` (House.mainPhotos, House.coverPhoto) |

## Shared Files (OWNED by scaffold — tasks must NOT edit these)

| File | Purpose |
|------|---------|
| `lib/types.ts` | All shared data models & interfaces |
''';

void main() {
  group('templateTableOwnedFiles — Task Registry table', () {
    test('task 90 → its two owned components (the real bug case)', () {
      final owned = templateTableOwnedFiles(registryTemplate, 90);
      expect(owned, {
        '/components/RoomList.tsx',
        '/components/ContactBox.tsx',
      });
    });

    test('task 89 → its four owned files, [id] path intact', () {
      final owned = templateTableOwnedFiles(registryTemplate, 89);
      expect(owned, {
        '/app/page.tsx',
        '/app/houses/[id]/page.tsx',
        '/components/HouseCard.tsx',
        '/lib/seedData.ts',
      });
    });

    test('single-file task', () {
      expect(templateTableOwnedFiles(registryTemplate, 91),
          {'/components/HousePhotos.tsx'});
    });

    test('shared "Consumed" contracts are NOT treated as owned', () {
      // Task 90 consumes lib/types.ts but does not own it.
      final owned = templateTableOwnedFiles(registryTemplate, 90);
      expect(owned.contains('/lib/types.ts'), isFalse);
    });

    test('unknown task → empty', () {
      expect(templateTableOwnedFiles(registryTemplate, 999), isEmpty);
    });

    test('no table at all → empty (bullet format handled elsewhere)', () {
      const bullets = '''
### 1. Task #7: X
- Owns: `/lib/features/task_7_x`
- Starter: `/lib/features/task_7_x/x_page.dart`
''';
      expect(templateTableOwnedFiles(bullets, 7), isEmpty);
    });
  });

  group('templateTableOwnedFiles — "Task-Owned Files" fallback', () {
    const ownedFiles = '''
## Task-Owned Files (each task fills in its own stub)

| File | Owned By |
|------|----------|
| `components/Foo.tsx` | #5 |
| `components/Bar.tsx` | #5, #6 |
| `components/Baz.tsx` | #6 |
''';

    test('maps files to their owning task (incl. shared ownership)', () {
      expect(templateTableOwnedFiles(ownedFiles, 5),
          {"/components/Foo.tsx", "/components/Bar.tsx"});
      expect(templateTableOwnedFiles(ownedFiles, 6),
          {"/components/Bar.tsx", "/components/Baz.tsx"});
    });
  });
}

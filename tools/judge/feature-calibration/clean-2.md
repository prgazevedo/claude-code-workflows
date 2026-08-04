## Context

Search results render titles only, and users open five wrong notes before the right one. The index already stores the first paragraph of each note.

## Goal

Each search result shows a two-line snippet from the stored first paragraph.

## Acceptance Criteria

- Results show at most 160 characters of snippet with the match highlighted.
- Notes with an empty first paragraph fall back to the title alone.
- Response size for a 20-result page stays under 64KB.

## Scope: out

- Touching the indexer; this reads the paragraph the index already stores. Existing result ordering is unchanged.

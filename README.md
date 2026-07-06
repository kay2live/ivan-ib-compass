# Ivan's IB Compass

A responsive IB study tracker for syllabus mastery, practice scores, focus gaps, and spaced-repetition flashcards.

## Features

- Physics HL, Mathematics AA HL, and Computer Science HL syllabus tracking
- School progress, personal mastery, and confidence tracking
- Practice score history and automatic focus-gap detection
- Spaced-repetition flashcards
- Supabase email authentication and per-user cloud sync with Row Level Security
- Responsive PWA layout for desktop and mobile

## Supabase setup

1. Create a Supabase project.
2. Run `supabase-schema.sql` in the Supabase SQL Editor.
3. Set the project URL and publishable key in `supabase-config.js`.
4. Add the deployed URL under Authentication → URL Configuration.

## Local preview

```powershell
python -m http.server 8765
```

Then open `http://127.0.0.1:8765/`.

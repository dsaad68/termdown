# Folder browsing

This page exists to give the file list something to browse. Press `q` to go back
to it, then press `d`.

## What `d` does

The file list normally shows **every** Markdown file in the folder you opened,
flat — `folders/nested/deeper.md` and all. `d` swaps that for the folders, one
level at a time:

- `Enter` steps into the selected folder and shows *its* folders. In this tour,
  `folders/` contains `nested/`, so stepping into it shows that.
- `Backspace` (or `←` / `h`) comes back out, landing on the folder you just
  left rather than at the top of the list.
- `../` is the same thing for the mouse — the top row of every level but the
  first.

Each row's right-hand column counts the Markdown files beneath that folder, at
any depth. Only folders that lead to one are listed at all, so you can never
step into a dead end.

## Getting to the files

`d` again leaves the browser with the file list narrowed to the folder you were
standing in, named relative to it — browsing is how you scope the list. `Esc`
widens it back to the whole tour.

A folder with nothing inside it has nothing to show you, so `Enter` on one hands
over its files directly instead of an empty level. `nested/` is such a folder:
step into `folders/`, then press `Enter` on `nested/`.

## Searching

`/` still searches every folder, wherever you are — the browser steps aside for
it, and clearing the query with `Esc` puts you back where you were.

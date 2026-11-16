# Forsaken section headings

The Forsaken sheet's section headings, drawn in Flat Earth Scribe (Nate Piekos, Blambot) as Android vector
drawables, with `headings.json` listing each heading's text, drawable name and size in dp at the heading size.

The font is licensed for desktop use only, so it must never be added to this repo or to either app. These pictures
are outlines only and hold no font. They're generated with the iOS PDFs by `scripts/render-forsaken-headings.swift`,
which needs a Mac with the font installed. Don't edit them by hand: change the heading list in the script, run it,
and commit the results for both apps.

Android: copy (or point a source set at) the `.xml` files as drawable resources, tint them Werewolf Rust (#855A4A),
scale them with the font scale, give each its heading as the content description, and fall back to text in
Grechen Fuemen only if a heading has no drawable. A test should check every sheet section has one.

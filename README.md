# delvermd

This project is supposed to turn a [Delver Lens](https://delverlab.com/) database into a markdown file with raw images.
At a point where your MTG collection turns into a rather static amount of cards, this is a great way to export and browse
your collection on a PC, and also to share it with friends who don't have an android phone.

## Dependencies

    pacman -Sy sqlite3 luarocks
    luarocks install lsqlite3

## Setup Databases

Export delver lens file from smartphone and save as mycards.sqlite.
Grab the latest [Delver Lens APK](https://apkpure.com/de/magic-the-gathering-mtg-card-scanner-delver-lens/delverslab.delverlens/), unpack it and save the file `res/raw/data.db` as `delver.sqlite`.

Your directory should now look like this:
    - ./delver.sqlite
    - ./mycards.sqlite
    - ./main.lua
    - ./README.md
    - ./LICENSE

## Run

    lua main.lua

## Thanks

- **Delver Lens**
It's by far the best card scanner and organizer out there - even without being opensource. If you have an Android-Phone and no card scanner yet, get it now!
I have tried many apps, but delver lens stands out for its good organized interface, the card detection algorithm and the clean sqlite-export of collections.

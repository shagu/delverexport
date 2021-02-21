# delverexport

This project is supposed to export a [Delver Lens](https://delverlab.com/) database into something readable on a PC. At a point where your MTG collection turns into a rather static amount of cards, this is a great way to export and browse your collection on a PC, and also to share it with friends who don't have an android phone.

## Dependencies

    pacman -Sy lua sqlite3 luarocks
    luarocks install dkjson
    luarocks install luasec
    luarocks install lsqlite3

## Run

  1. Copy the latest APK of DelverLens into the `./input` directory.
  2. Copy your DelverLens backup file into the `./input` directory.
  3. Run `make`

## Thanks

- **Delver Lens**
It's by far the best card scanner and organizer out there - even without being opensource. If you have an Android-Phone and no card scanner yet, get it now!
I have tried many apps, but delver lens stands out for its good organized interface, the card detection algorithm and the clean sqlite-export of collections.

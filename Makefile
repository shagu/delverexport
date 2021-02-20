all: update delver

update:
	@echo "Preparing Caches"
	@mkdir -p cache
	@echo " - Extracting DelverLens Database"
	@unzip -jp $(shell ls input/delverlab.*.apk | head -n1) res/raw/data.db > cache/delver.sqlite
	@echo " - Moving DelverLens Card Backup"
	@cp -f $(shell ls input/*.dlens.bin | head -n1) cache/cards.sqlite

delver:
	lua ./delver.lua

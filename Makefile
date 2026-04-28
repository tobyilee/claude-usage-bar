APP_NAME = ClaudeUsageBar
BUILD_DIR = .build/release
APP_BUNDLE = build/$(APP_NAME).app

.PHONY: run build app install clean

run:
	swift run

build:
	swift build -c release

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	@# SPM emits the resource bundle next to the executable; copy whatever it produced.
	@for b in $(BUILD_DIR)/*.bundle; do \
		if [ -e "$$b" ]; then cp -R "$$b" $(APP_BUNDLE)/Contents/Resources/; fi; \
	done
	@echo ""
	@echo "Built $(APP_BUNDLE)"
	@echo "Run with:    open $(APP_BUNDLE)"
	@echo "Install:     make install"

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "Installed to /Applications/$(APP_NAME).app"
	@echo "Add to Login Items in System Settings to start at login."

clean:
	swift package clean
	rm -rf build

.PHONY: build run clean release package dmg icon

# Debug build
build:
	swift build

# Clean and rebuild
clean:
	swift package clean
	rm -rf .build AgentTerms.app AgentTerms.dmg AgentTerms-macOS.zip

# Release build
release:
	swift build -c release

# Build and run the app (debug)
run: build
	@killall AgentTerms 2>/dev/null || true
	@sleep 1
	@$(MAKE) _assemble MODE=debug
	@open AgentTerms.app

# Assemble .app bundle from build output
_assemble:
	@mkdir -p AgentTerms.app/Contents/MacOS AgentTerms.app/Contents/Resources
	@cp .build/arm64-apple-macosx/$(MODE)/AgentTerms AgentTerms.app/Contents/MacOS/AgentTerms
	@rm -rf AgentTerms.app/Contents/MacOS/AgentTerms_AgentTerms.bundle AgentTerms.app/Contents/Resources/AgentTerms_AgentTerms.bundle
	@cp -R .build/arm64-apple-macosx/$(MODE)/AgentTerms_AgentTerms.bundle AgentTerms.app/Contents/MacOS/AgentTerms_AgentTerms.bundle
	@cp -R .build/arm64-apple-macosx/$(MODE)/AgentTerms_AgentTerms.bundle AgentTerms.app/Contents/Resources/AgentTerms_AgentTerms.bundle
	@cp Info.plist AgentTerms.app/Contents/Info.plist 2>/dev/null || true
	@test -f AgentTerms.app/Contents/Resources/AppIcon.icns || true

# Package release .app bundle
package: release
	@$(MAKE) _assemble MODE=release
	@echo "AgentTerms.app assembled (release)."

# Create DMG for distribution
dmg: package
	@rm -rf dmg_tmp AgentTerms.dmg
	@mkdir -p dmg_tmp
	@cp -R AgentTerms.app dmg_tmp/
	@ln -s /Applications dmg_tmp/Applications
	@hdiutil create -volname "AgentTerms" -srcfolder dmg_tmp -ov -format UDZO AgentTerms.dmg
	@rm -rf dmg_tmp
	@echo "AgentTerms.dmg created."

# Create zip for distribution
zip: package
	@rm -f AgentTerms-macOS.zip
	@zip -r AgentTerms-macOS.zip AgentTerms.app
	@echo "AgentTerms-macOS.zip created."

# Generate app icon from logo.png (requires Pillow: pip3 install Pillow)
icon:
	@python3 -c "\
	from PIL import Image, ImageDraw; \
	img = Image.open('logo.png').resize((1024, 1024), Image.LANCZOS).convert('RGBA'); \
	mask = Image.new('L', (1024, 1024), 0); \
	ImageDraw.Draw(mask).rounded_rectangle([(0,0),(1023,1023)], radius=225, fill=255); \
	img.putalpha(mask); \
	img.save('icon_rounded.png')"
	@mkdir -p AppIcon.iconset
	@sips -z 16 16 icon_rounded.png --out AppIcon.iconset/icon_16x16.png
	@sips -z 32 32 icon_rounded.png --out AppIcon.iconset/icon_16x16@2x.png
	@sips -z 32 32 icon_rounded.png --out AppIcon.iconset/icon_32x32.png
	@sips -z 64 64 icon_rounded.png --out AppIcon.iconset/icon_32x32@2x.png
	@sips -z 128 128 icon_rounded.png --out AppIcon.iconset/icon_128x128.png
	@sips -z 256 256 icon_rounded.png --out AppIcon.iconset/icon_128x128@2x.png
	@sips -z 256 256 icon_rounded.png --out AppIcon.iconset/icon_256x256.png
	@sips -z 512 512 icon_rounded.png --out AppIcon.iconset/icon_256x256@2x.png
	@sips -z 512 512 icon_rounded.png --out AppIcon.iconset/icon_512x512.png
	@sips -z 1024 1024 icon_rounded.png --out AppIcon.iconset/icon_512x512@2x.png
	@iconutil -c icns AppIcon.iconset -o AgentTerms.app/Contents/Resources/AppIcon.icns
	@rm -rf AppIcon.iconset icon_rounded.png
	@echo "Icon generated."

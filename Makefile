SIMULATOR ?= iPhone 17 Pro

.PHONY: project open test icon

## Xcode-Projekt nach Änderungen an project.yml neu erzeugen (braucht: brew install xcodegen)
project:
	xcodegen generate

open:
	open Feins.xcodeproj

## Unit- und UI-Tests im Simulator
test:
	xcodebuild test -project Feins.xcodeproj -scheme Feins \
		-destination "platform=iOS Simulator,name=$(SIMULATOR)" \
		CODE_SIGNING_ALLOWED=NO

## App-Icon und Smiley neu zeichnen (braucht Python + Pillow)
icon:
	python3 scripts/generate_icon.py build/icon
	cp build/icon/AppIcon*.png Feins/Resources/Assets.xcassets/AppIcon.appiconset/
	for n in Smiley SmileyTongue; do cp build/icon/$$n@*.png Feins/Resources/Assets.xcassets/$$n.imageset/; done

.PHONY: build uishot ci

DERIVED=build
SCHEME?=SynapseTasks
DEVICE?=iPhone 15
CONFIG?=Debug

build:
	@xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) \
	-destination "platform=iOS Simulator,name=$(DEVICE)" \
	-derivedDataPath $(DERIVED) -quiet build

uishot:
	@DEVICE_NAME="$(DEVICE)" WEEKDAY_FOR_WEEKLY=3 CONFIG=$(CONFIG) ./scripts/ui_capture.sh

ci:
	@echo "Run GitHub Actions workflow 'UI Capture' from the Actions tab or push to main/develop."

# Makefile for GeminiInsightApp

CC = clang
CFLAGS = -Wall -framework Cocoa -lcurl -fobjc-arc
SOURCES = main.m API_Client.c cJSON.c
executable = GeminiInsightApp

all: $(executable)

$(executable): $(SOURCES)
	$(CC) $(CFLAGS) $(SOURCES) -o $(executable)


app: $(executable)
	mkdir -p $(executable).app/Contents/MacOS
	mkdir -p $(executable).app/Contents/Resources
	cp $(executable) $(executable).app/Contents/MacOS/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(executable).app/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(executable).app/Contents/Info.plist
	@echo '<plist version="1.0">' >> $(executable).app/Contents/Info.plist
	@echo '<dict>' >> $(executable).app/Contents/Info.plist
	@echo '    <key>CFBundleExecutable</key>' >> $(executable).app/Contents/Info.plist
	@echo '    <string>$(executable)</string>' >> $(executable).app/Contents/Info.plist
	@echo '    <key>CFBundleIdentifier</key>' >> $(executable).app/Contents/Info.plist
	@echo '    <string>com.example.$(executable)</string>' >> $(executable).app/Contents/Info.plist
	@echo '    <key>CFBundleName</key>' >> $(executable).app/Contents/Info.plist
	@echo '    <string>$(executable)</string>' >> $(executable).app/Contents/Info.plist
	@echo '    <key>CFBundlePackageType</key>' >> $(executable).app/Contents/Info.plist
	@echo '    <string>APPL</string>' >> $(executable).app/Contents/Info.plist
	@echo '</dict>' >> $(executable).app/Contents/Info.plist
	@echo '</plist>' >> $(executable).app/Contents/Info.plist
	@echo "App bundle created at $(executable).app"

clean:
	rm -f $(executable)
	rm -rf $(executable).app

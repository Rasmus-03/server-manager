PREFIX ?= /usr/local
APP_NAME = server-manager
BIN_DIR = $(PREFIX)/bin
SHARE_DIR = $(PREFIX)/share

all:
	@echo "Run 'make install' to install Server Manager for Linux."
	@echo "Run 'make run' to start without installing."

install:
	install -d $(DESTDIR)$(BIN_DIR)
	install -d $(DESTDIR)$(SHARE_DIR)/applications
	install -d $(DESTDIR)$(SHARE_DIR)/$(APP_NAME)
	cp -r server-manager.py core/ ui/ $(DESTDIR)$(SHARE_DIR)/$(APP_NAME)/
	install -m 755 org.server-manager.sh $(DESTDIR)$(BIN_DIR)/$(APP_NAME)
	install -m 644 org.server-manager.desktop $(DESTDIR)$(SHARE_DIR)/applications/
	sed -i "s|Exec=|Exec=$(BIN_DIR)/$(APP_NAME)|" $(DESTDIR)$(SHARE_DIR)/applications/org.server-manager.desktop
	@echo "Installed. Run 'server-manager' or launch from app menu."

uninstall:
	rm -rf $(DESTDIR)$(SHARE_DIR)/$(APP_NAME)
	rm -f $(DESTDIR)$(BIN_DIR)/$(APP_NAME)
	rm -f $(DESTDIR)$(SHARE_DIR)/applications/org.server-manager.desktop

run:
	python3 server-manager.py

.PHONY: all install uninstall run

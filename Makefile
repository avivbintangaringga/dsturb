all:
	@echo "Run 'make install' for installation."
	@echo "Run 'make uninstall' for uninstallation."

install:
	install -Dm755 dsturb /usr/bin/dsturb
	install -Dm644 version /usr/share/dsturb/version

uninstall:
	rm -f /usr/bin/dsturb
	rm -rf /usr/share/dsturb
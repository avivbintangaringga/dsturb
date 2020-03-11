all:
	@echo "Run 'make install' for installation."
	@echo "Run 'make uninstall' for uninstallation."

install:
	install -Dm755 dsturb /usr/bin/dsturb

uninstall:
	rm -f /usr/bin/dsturb

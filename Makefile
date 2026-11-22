.PHONY: install check uninstall help

help:
	@echo "Targets:"
	@echo "  make install   - install scripts to ~/.local/bin + desktop entry"
	@echo "  make check     - verify prerequisites only"
	@echo "  make uninstall - remove installed scripts and desktop entry"

install:
	./install.sh

check:
	./install.sh --check

uninstall:
	rm -f $(HOME)/.local/bin/waydroid-ui $(HOME)/.local/bin/waydroid-emu $(HOME)/.local/bin/waydroid-tune
	rm -f $(HOME)/.local/share/applications/waydroid-ui.desktop
	@echo "Removed installed scripts and desktop entry."
PREFIX  ?= /usr/local
BINDIR   = $(DESTDIR)$(PREFIX)/bin
SCRIPTS  = $(wildcard bin/*)
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "unknown")

install:
	install -d $(BINDIR)
	install -m 0755 $(SCRIPTS) $(BINDIR)
	@echo "quectel-scripts $(VERSION) installed in $(BINDIR)"

uninstall:
	rm -f $(addprefix $(BINDIR)/,$(notdir $(SCRIPTS)))
	@echo "quectel-scripts uninstalled from $(BINDIR)"

list:
	@echo "quectel-scripts $(VERSION)"
	@ls -1 bin/

.PHONY: install uninstall list

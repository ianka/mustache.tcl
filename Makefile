.PHONY: install

INSTALL_PATH=/usr/share/tcl/mustache/

install:
	mkdir -p $(INSTALL_PATH)
	cp mustache.tcl pkgIndex.tcl examples.tcl COPYING $(INSTALL_PATH)

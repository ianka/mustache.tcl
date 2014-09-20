.PHONY: all clean install

INSTALL_PATH=/usr/share/tcl/mustache/
MAN_INSTALL_PATH=/usr/share/man/mann/

all:
	./makedocs.tcl

clean:
	-rm mustache.html mustache.n

install: all
	mkdir -p $(INSTALL_PATH)
	cp mustache.tcl pkgIndex.tcl examples.tcl README COPYING mustache.html $(INSTALL_PATH)
	mkdir -p $(MAN_INSTALL_PATH)
	cp mustache.n $(MAN_INSTALL_PATH)

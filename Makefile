dist/build/lib-nvml/nvml.cmxa:
	obuild configure --enable-tests
	obuild build

install:
	ocamlfind install nvml lib/META \
		$(wildcard dist/build/lib-nvml/*) \
		$(wildcard dist/build/lib-nvml.lwt/*) \
		$(wildcard dist/build/lib-nvml.unix/*)

uninstall:
	ocamlfind remove nvml

.PHONY: clean test
clean:
	rm -rf dist

test:
	obuild test --output

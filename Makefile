all: build

.PHONY: install uninstall clean

NAME=nvml
J=4

setup.data: setup.ml
	ocaml setup.ml -configure

build: setup.data setup.ml
	ocaml setup.ml -build -j $(J)

install: setup.data setup.ml
	ocaml setup.ml -install

uninstall:
	ocamlfind remove $(NAME)

reinstall: setup.ml
	ocamlfind remove $(NAME) || true
	ocaml setup.ml -reinstall

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log

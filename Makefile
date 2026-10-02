# Configuration.
PROJECT=Axum/Elm Template
OS=darwin
ARCH=arm64


# Resolve OS and ARCH
ARCH_amd64 := x86_64
ARCH_arm64 := aarch64
OS_linux   := unknown-linux-musl
OS_darwin  := apple-darwin
OS_windows := pc-windows-gnu
RUST_ARCH  := $(ARCH_$(ARCH))
RUST_OS    := $(OS_$(OS))
TARGET     := $(RUST_ARCH)-$(RUST_OS)
$(if $(RUST_ARCH),,$(error unknown ARCH '$(ARCH)'))
$(if $(RUST_OS),,$(error unknown OS '$(OS)'))

.PHONY: help ## prints this message
help:
	@echo
	@echo "$(PROJECT) CLI"
	@echo
	@printf 'make \033[34m...\033[0m\n'
	@grep '^.PHONY: ' Makefile | sed 's/^.PHONY: //' | awk '{split($$0, a, " ## "); printf "  \033[34m%-10s\033[0m%s\n", a[1], a[2]}'
	@echo

.PHONY: release
release: client;

.PHONY: client ## builds client
client: genelm
	cd client && tailwindcss -i app.css -o target/app.css
	cd client && elm make --optimize src/Main.elm --output target/app.js
	cd client && cp index.html target/index.html
	mkdir -p target
	rm -rf target/client && cp -r client/target target/client

.PHONY: genelm ## builds elm bindings
genelm: server
	mkdir -p client/src/Api
	target/server genelm > client/src/Api/Types.elm

.PHONY: server ## builds server
server:
	cd server && cargo zigbuild --release --target $(TARGET)
	mkdir -p target
	cp server/target/$(TARGET)/release/server target/server

.PHONY: format ## formats server & client code
format:
	cd client && elm-format . --yes
	cd server && cargo fmt

.PHONY: clean ## cleans
clean:
	rm -rf target
	rm -rf server/target
	rm -rf client/elm-stuff client/target

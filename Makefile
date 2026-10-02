# Configuration.
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


.PHONY: all
all: server client

.PHONY: server
server:
	cd server && cargo zigbuild --release --target $(TARGET)

.PHONY: client
client:
	cd client && tailwindcss -i app.css -o target/app.css
	cd client && elm make --optimize src/Main.elm --output target/app.js
	cd client && cp index.html target/index.html

.PHONY: format
format:
	cd client && elm-format . --yes
	cd server && cargo fmt

.PHONY: clean
clean:
	rm -rf server/target
	rm -rf client/elm-stuff client/target

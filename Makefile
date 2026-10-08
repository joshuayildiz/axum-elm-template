# Configuration.
PROJECT=Axum/Elm Template
OS=darwin
ARCH=arm64

# Throwaway database for the coverage run. Override to point elsewhere.
COVERAGE_DATABASE_URL ?= postgres://localhost/axum_elm_template_test


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



.PHONY: dev ## runs local dev servers with hot reload
dev:
	mkdir -p client/target
	cp client/index.html client/target/index.html
	dekit up && dekit attach

.PHONY: release
release: client;

.PHONY: client ## builds client
client: genelm
	cd client && tailwindcss -i app.css -o target/app.css --minify
	cd client && elm make --optimize src/Main.elm --output target/app.js
	cd client && terser target/app.js --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' --output target/app.tmp.js
	cd client && terser target/app.tmp.js --mangle --output target/app.js
	cd client && rm target/app.tmp.js
	cd client && cp index.html target/index.html
	mkdir -p target
	rm -rf target/client && cp -r client/target target/client

.PHONY: genelm ## builds elm bindings
genelm: server
	mkdir -p client/src/Api
	cd server && target/$(TARGET)/release/server genelm > ../client/src/Api/Types.elm

.PHONY: server ## builds server
server:
	cd server && cargo zigbuild --release --target $(TARGET)
	mkdir -p target
	cp server/target/$(TARGET)/release/server target/server

.PHONY: install ## installs client dev dependencies
install:
	cd client && npm install

.PHONY: format ## formats server & client code
format:
	cd client && elm-format . --yes
	cd server && cargo fmt

.PHONY: coverage ## runs server tests with a coverage report
coverage:
	createdb axum_elm_template_test 2>/dev/null || true
	cd server && DATABASE_URL="$(COVERAGE_DATABASE_URL)" sqlx migrate run
	cd server && \
		DATABASE_URL="$(COVERAGE_DATABASE_URL)" \
		JWT_SECRET=coverage-test-secret \
		DEPLOY_ENV=local \
		OTEL_EXPORTER_OTLP_ENDPOINT= \
		cargo llvm-cov --html
	@echo "Report: server/target/llvm-cov/html/index.html"

.PHONY: clean ## cleans
clean:
	rm -rf target
	rm -rf server/target
	rm -rf client/elm-stuff client/target

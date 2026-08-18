# Flutter for Sailfish OS
#
#   make FLUTTER=3.44.0 engine | runtime | hello | deploy
#
# Add a version: copy versions/<prev>/pin.env, ln -s patches/<prev> patches/<ver>

ifeq ($(FLUTTER),)
  ifneq ($(filter-out help,$(MAKECMDGOALS)),)
    $(error set FLUTTER=<ver>, e.g. make FLUTTER=3.44.0 $(firstword $(MAKECMDGOALS)))
  endif
else ifeq ($(wildcard versions/$(FLUTTER)/pin.env),)
  $(error unknown Flutter version '$(FLUTTER)' (no versions/$(FLUTTER)/pin.env))
else
  include versions/$(FLUTTER)/pin.env
endif

SFOS   ?= 5.1.0.11
ARCH   ?= aarch64
DEVICE ?= defaultuser@192.168.1.177
APP    ?=

export FLUTTER
export FORCE
export V

RUNTIME   := versions/$(FLUTTER)/runtime
ENGINE_SO := versions/$(FLUTTER)/engine/libflutter_engine.so
RELEASE   ?= 1

stamp = sed -e 's|@FLUTTER_VERSION@|$(FLUTTER)|g' -e 's|@RELEASE@|$(RELEASE)|g'

.DEFAULT_GOAL := help
.PHONY: help all engine embedder runtime hello app deploy clean

help:
	@echo "usage: make FLUTTER=<ver> engine | runtime | hello | deploy"
	@echo "       make FLUTTER=<ver> app APP=<dir>"
	@echo "  SFOS=$(SFOS)  ARCH=$(ARCH)  DEVICE=$(DEVICE)"
	@echo "versions:"
	@ls -1 versions/*/pin.env | sed 's|versions/||;s|/pin.env||' | sed 's/^/  /'

all: runtime hello

# Always run the script so a pin change / FORCE=1 is not skipped as "up to date".
engine:
	./scripts/build-engine.sh

$(ENGINE_SO):
	./scripts/build-engine.sh

embedder:
	./scripts/fetch-embedder.sh

runtime: $(ENGINE_SO) embedder
	mkdir -p $(RUNTIME)/rpm $(RUNTIME)/cmake
	$(stamp) template/runtime/flutter-sfos.spec.in > $(RUNTIME)/rpm/flutter-sfos.spec
	$(stamp) template/runtime/flutter-sfos-aot.sh.in > $(RUNTIME)/flutter-sfos-aot
	chmod +x $(RUNTIME)/flutter-sfos-aot
	cp -f template/runtime/cmake/flutter-sfos-config.cmake.in $(RUNTIME)/cmake/
	sfosbuild $(SFOS) $(ARCH) $(RUNTIME)

hello: runtime
	FLUTTER_VERSION=$(FLUTTER) \
	FLUTTER_SFOS_RPMS=$(abspath versions/$(FLUTTER)/runtime/rpms) \
		./examples/hello/elinux/build.sh

app: runtime
	@test -n "$(APP)" || { echo "usage: make FLUTTER=<ver> app APP=<dir>" >&2; exit 1; }
	@test -x "$(APP)/elinux/build.sh" || { \
		echo "missing $(APP)/elinux/build.sh — copy template/elinux, template/rpm, template/.sfosbuild" >&2; exit 1; }
	FLUTTER_VERSION=$(FLUTTER) \
	FLUTTER_SFOS_RPMS=$(abspath versions/$(FLUTTER)/runtime/rpms) \
		"$(APP)/elinux/build.sh"

deploy: runtime hello
	sfosbuild deploy $(DEVICE) $(RUNTIME)
	FLUTTER_VERSION=$(FLUTTER) DEVICE=$(DEVICE) \
	FLUTTER_SFOS_RPMS=$(abspath versions/$(FLUTTER)/runtime/rpms) \
		./examples/hello/elinux/build.sh deploy

clean:
	@test -n "$(FLUTTER)" || { echo "set FLUTTER=<ver>" >&2; exit 1; }
	rm -rf $(RUNTIME)
	./examples/hello/elinux/build.sh clean

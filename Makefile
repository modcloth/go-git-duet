SHELL := /bin/bash
UNAME := $(shell uname | tr '[:upper:]' '[:lower:]')
SUDO ?= sudo
DEBIAN_FRONTEND := noninteractive
G := github.com/modcloth/go-git-duet
PACKAGES := \
  $(G) \
  $(G)/version
EXECUTABLES := \
  $(G)/git-duet \
  $(G)/git-solo
REV_VAR := $(G)/version.RevString
VERSION_VAR := $(G)/version.VersionString
BRANCH_VAR := $(G)/version.BranchString
REPO_VERSION := $(shell git describe --always --dirty --tags)
REPO_REV := $(shell git rev-parse --sq HEAD)
REPO_BRANCH := $(shell git rev-parse -q --abbrev-ref HEAD)
GOBUILD_VERSION_ARGS := -ldflags "\
  -X $(REV_VAR) $(REPO_REV) \
  -X $(VERSION_VAR) $(REPO_VERSION) \
  -X $(BRANCH_VAR) $(REPO_BRANCH)"
LD_LIBRARY_PATH := /usr/local/lib:$(LD_LIBRARY_PATH)

BATS_OUT_FORMAT=$(shell bash -c "echo $${CI+--tap}")
GOPATH := $(shell echo $${GOPATH%%:*})
GOBIN := $(GOPATH)/bin
PATH := $(GOBIN):$(PATH)

.PHONY: default test
default: test
test: build fmtpolice bats

.PHONY: savedeps
savedeps:
	godep save -copy=false ./...

.PHONY: godep
godep:
	go get github.com/tools/godep

.PHONY: deps
deps: godep
	$(GOBIN)/godep restore
	go get github.com/golang/lint/golint
	go get github.com/libgit2/git2go
	@echo "installing bats..."
	@if ! ls ./bats/bin/bats >/dev/null 2>&1 ; then \
	  git clone https://github.com/sstephenson/bats.git && \
	  rm -rf ./bats/test ; \
	  fi

.PHONY: libgit2
libgit2:
	@echo "installing libgit2"
	@if [[ "$(UNAME)" == "darwin" ]] ; then \
	  brew install libgit2 --HEAD && brew install pkg-config  && brew install cmake ; fi
	@if [[ "$(UNAME)" == "linux" ]] ; then $(MAKE) libgit2-linux ; fi

.PHONY: libgit2-linux
libgit2-linux:
	$(SUDO) apt-get install -y --no-install-recommends cmake pkg-config
	mkdir -p deps && \
	  pushd deps >/dev/null && \
	  git clone --depth 1 https://github.com/libgit2/libgit2.git && \
	  cd libgit2 && \
	  mkdir build && cd build && \
	  $(SUDO) cmake .. && \
	  $(SUDO) cmake --build . && \
	  $(SUDO) cmake --build . --target install && \
	  popd >/dev/null && \
	  $(SUDO) rm -rf deps

.PHONY: update
update:
	@if [[ "$(UNAME)" == "darwin" ]] ; then brew uninstall libgit2 && brew install libgit2 --HEAD && brew uninstall pkg-config && brew install pkg-config ; fi

.PHONY: fmtpolice
fmtpolice: deps fmt lint

.PHONY: fmt
fmt:
	@echo "----------"
	@echo "checking fmt"
	@set -e ; \
	  for f in $(shell git ls-files '*.go'); do \
	  gofmt $$f | diff -u $$f - ; \
	  done

.PHONY: lint
lint:
	@echo "----------"
	@echo "checking lint"
	@for file in $(shell git ls-files '*.go') ; do \
	  if [[ "$$($(GOPATH)/bin/golint $$file)" =~ ^[[:blank:]]*$$ ]] ; then \
	  echo yayyy >/dev/null ; \
	  else $(MAKE) lintv && exit 1 ; fi \
	  done

.PHONY: lintv
lintv:
	@echo "----------"
	@for file in $(shell git ls-files '*.go') ; do $(GOPATH)/bin/golint $$file ; done

.PHONY: bats
bats:
	@echo "----------"
	./bats/bin/bats $(BATS_OUT_FORMAT) $(shell find . -type f -name '*.bats')

.PHONY: binclean
binclean:
	rm -f $(GOBIN)/git-duet
	rm -f $(GOBIN)/git-solo

.PHONY: build
build: binclean deps
	go install $(GOBUILD_VERSION_ARGS) $(GO_TAG_ARGS) $(PACKAGES) $(EXECUTABLES)

.PHONY: gopath
gopath:
	@echo  "\$$GOPATH = $(GOPATH)"

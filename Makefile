SHELL := /bin/bash
UNAME := $(shell uname | tr '[:upper:]' '[:lower:]')
SUDO ?= sudo
DEBIAN_FRONTEND := noninteractive
G := github.com/modcloth/go-git-duet
TARGETS := \
  $(G) \
  $(G)/version
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
GINKGO_PATH ?= "."
BATS_INSTALL_DIR ?= /usr/local
LD_LIBRARY_PATH := /usr/local/lib:$(LD_LIBRARY_PATH)

BATS_OUT_FORMAT=$(shell bash -c "echo $${CI+--tap}")
GOBIN := $(GOPATH)/bin

export GINKGO_PATH
export GOPATH
export GOBIN
export UNAME
export DEBIAN_FRONTEND
export LD_LIBRARY_PATH

.PHONY: default test
default: test
test: build fmtpolice ginkgo bats

.PHONY: savedeps
savedeps:
	godep save -copy=false ./...

.PHONY: godep
godep:
	go get github.com/tools/godep

.PHONY: deps
deps: godep libgit2
	$(GOBIN)/godep restore
	go get github.com/golang/lint/golint
	go get github.com/onsi/ginkgo/ginkgo
	go get github.com/onsi/gomega
	@echo "installing bats..."
	@if ! which bats >/dev/null ; then \
	  git clone https://github.com/sstephenson/bats.git && \
	  (cd bats && $(SUDO) ./install.sh $(BATS_INSTALL_DIR)) && \
	  rm -rf bats ; \
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
	  rm -rf deps

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

.PHONY: ginkgo
ginkgo:
	@echo "----------"
	@if [[ "$(GINKGO_PATH)" == "." ]] ; then \
	  echo "$(GOPATH)/bin/ginkgo -nodes=10 -noisyPendings -race -r ." && \
	  $(GOPATH)/bin/ginkgo -nodes=10 -noisyPendings -race -r . ; \
	  else echo "$(GOPATH)/bin/ginkgo -nodes=10 -noisyPendings -race --v $(GINKGO_PATH)" && \
	  $(GOPATH)/bin/ginkgo -nodes=10 -noisyPendings -race --v $(GINKGO_PATH) ; \
	  fi

.PHONY: bats
bats:
	@echo "----------"
	$(BATS_INSTALL_DIR)/bin/bats $(BATS_OUT_FORMAT) $(shell find . -type f -name '*.bats')

.PHONY: binclean
biclean:
	rm -f $(GOBIN)/git-duet
	rm -f $(GOBIN)/git-solo

.PHONY: build
build: binclean deps
	go build -o $(GOBIN)/git-duet $(GOBUILD_VERSION_ARGS) $(GO_TAG_ARGS) $(G)/git-duet
	go build -o $(GOBIN)/git-solo $(GOBUILD_VERSION_ARGS) $(GO_TAG_ARGS) $(G)/git-solo
	go install $(GOBUILD_VERSION_ARGS) $(GO_TAG_ARGS) $(TARGETS)

.PHONY: gopath
gopath:
	@echo  "\$$GOPATH = $(GOPATH)"

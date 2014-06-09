all: clean build test

clean: $(BUILD_DIR)
	go clean -i ./...

build: deps $(BUILD_DIR)
	go install ./...

savedeps:
	godep save -copy=false ./...

deps:
	godep restore

test: deps
	go test
	bats test

fmtpolice:
	set -e ; for f in $(shell git ls-files '*.go'); do gofmt $$f | diff -u $$f - ; done
	fail=0 ; for f in $(shell git ls-files '*.go'); do v="$$(golint $$f)" ; if [ ! -z "$$v" ] ; then echo "$$v" ; fail=1 ; fi ; done ; [ $$fail = 0 ]

.PHONY: all clean build test deps savedeps fmtpolice

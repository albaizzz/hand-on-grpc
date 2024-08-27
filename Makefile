# Collection of tools to make development process blazing very fast, lol

VERSION := $(shell git describe --tags)
SHORTVERSION := $(shell git tag)
BUILD := $(shell git rev-parse --short HEAD)
PROJECTNAME := $(shell basename "$(PWD)")
DOCKERIMAGE := $(subst _,,$(PROJECTNAME))

# Go related variables.
BASEDIR := $(shell pwd)
# GOBASE := $(shell pwd)
# GOPATH := $(PATH)/vendor:$(GOBASE)
BINPATH := $(BASEDIR)/bin
# GOFILES := $(wildcard *.go)

# Use linker flags to provide version/build settings
LDFLAGS=-ldflags "-X=main.Version=$(VERSION) -X=main.Build=$(BUILD)"

# Redirect error output to a file, so we can show it in development mode.
STDERR := /tmp/.$(PROJECTNAME)-stderr.txt

# PID file will keep the process id of the server
PID := /tmp/.$(PROJECTNAME).pid

# Make is verbose in Linux. Make it silent.
MAKEFLAGS += --silent

ifeq (run,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "run"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):;@:)
endif

.PHONY: all
all: help

##create new domains context
create-domain:
	@echo "> Create new domain name : "$(name)
	@mkdir ./internal/domains/$(name)
	@touch ./internal/domains/$(name)/index.go
	echo  "package $(name)" >> ./internal/domains/$(name)/index.go
	@touch ./internal/domains/$(name)/repository.go
	echo  "package $(name)" >> ./internal/domains/$(name)/repository.go
	@touch ./internal/domains/$(name)/$(name)_repository.go
	echo  "package $(name)" >> ./internal/domains/$(name)/$(name)_repository.go
	@touch ./internal/domains/$(name)/$(name)_service.go
	echo  "package $(name)" >> ./internal/domains/$(name)/$(name)_service.go
	@touch ./internal/domains/$(name)/payload.go
	echo  "package $(name)" >> ./internal/domains/$(name)/payload.go
	@touch ./internal/domains/$(name)/response.go
	echo  "package $(name)" >> ./internal/domains/$(name)/response.go

## check-variable: Print all global variable
check-variable:
	@echo " > BASEDIR=$(BASEDIR)"
	@echo " > VERSION=$(VERSION)"
	@echo " > BUILD=$(BUILD)"
	@echo " > PROJECTNAME=$(PROJECTNAME)"
	@echo " > LDFLAGS=$(LDFLAGS)"
	@echo " > DOCKERIMAGE=$(DOCKERIMAGE)"
	@echo " > GOPATH=$(GOPATH)"

## install: Install missing dependencies
install: go-get

## start-dev: Start server in development mode
start-dev:
	@echo " > Building binary..."
	@go build -o $(BINPATH)/$(PROJECTNAME)
	@echo " > Starting server..."
	@-$(BINPATH)/$(PROJECTNAME) start --config $(BASEDIR)/config.yaml

## start: Start server
start:
	@echo " > $(PROJECTNAME) is available at $(ADDR)"
	@-$(BINPATH)/$(PROJECTNAME) start 2>&1 & echo $$! > $(PID)
	@cat $(PID) | sed "/^/s/^/  \>  PID: /"

## stop: Stop server
stop:
	@echo " > stop server"
	@-touch $(PID)
	@-kill `cat $(PID)` 2> /dev/null || true
	@-rm $(PID)

## restart: Restart server
restart: stop-server start-server

## compile: Compile the binary.
compile:
	@-touch $(STDERR)
	@-rm $(STDERR)
	@-$(MAKE) -s go-compile 2> $(STDERR)
	@cat $(STDERR) | sed -e '1s/.*/\nError:\n/'  | sed 's/make\[.*/ /' | sed "/^/s/^/     /" 1>&2

## clean: Clean build files. Runs `go clean` internally.
clean:
	@-rm $(GOBIN)/$(PROJECTNAME) 2> /dev/null
	@-$(MAKE) go-clean

## create-note: Create some notes. e.g; make create-note note="today will be a good fucking day"
create-note:
	@echo "$(shell date) => $(note)" >> NOTES.txt

get-protobuf:
	@go install google.golang.org/protobuf/proto
	@go install google.golang.org/protobuf/cmd/protoc-gen-go

go-grpc-gateway:
	@go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway
	@go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2
	@go install google.golang.org/protobuf/cmd/protoc-gen-go
	@go install google.golang.org/grpc/cmd/protoc-gen-go-grpc

generate-proto:
	@echo " > Generate proto files"
	@protoc --proto_path=proto/v1 \
	--proto_path=proto \
	--go_out=pkg/v1 --go_opt=paths=source_relative \
    --go-grpc_out=pkg/v1 --go-grpc_opt=paths=source_relative \
	--swagger_out=logtostderr=true:pkg/v1 \
	--grpc-gateway_out=logtostderr=true:pkg \
	proto/v1/*.proto
	
## generate-uml: generate class diagram
generate-uml:
	@goplantuml -recursive -title Microservice_Catalog_Diagram \
	./pkg/cmd \
	./pkg/model \
	./pkg/protocol \
	./pkg/repository \
	./pkg/service \
	./commons \
	> microservice_catalog_diagram.puml

## docker-build: Build an image from a Dockerfile
docker-build:
	@docker build --pull --rm -f "Dockerfile" -t $(DOCKERIMAGE):$(VERSION) "."

## docker-run: Run a command in a new container
docker-run:
	@docker run --rm -p 8001:8001 -p 8002:8002 --name $(PROJECTNAME) --env-file $(BASEDIR)/.env $(DOCKERIMAGE):$(VERSION)

## test: Run unit test
test:
	@go test -v -cover -covermode=atomic ./...

go-compile: go-get go-build go-clean

go-get:
	@echo " > Checking if there is any missing dependencies..."
	go mod tidy

go-build:
	@echo " > Building binary..."
	@-CGO_ENABLED=0 GOOS=linux go build $(LDFLAGS) -a -installsuffix cgo -o $(BINPATH)/$(PROJECTNAME) main.go

go-clean:
	@echo " > Cleaning build cache"
	@go clean

inject-proto-tag:
	for filename in ./pkg/api/*pb.go; do \
		protoc-go-inject-tag -input=$$filename ; \
	done

help: Makefile
	@echo
	@echo " Choose a command run in "$(PROJECTNAME)":"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo
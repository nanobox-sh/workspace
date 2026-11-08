IMAGE ?= ghcr.io/nanobox-sh/workspace
TAG   ?= dev

.PHONY: build test shell versions

build:
	docker build -t $(IMAGE):$(TAG) .

test: build
	test/smoke.sh $(IMAGE):$(TAG)

shell: build
	docker run --rm -it --user 1000:1000 -v /var/run/docker.sock:/var/run/docker.sock $(IMAGE):$(TAG)

versions: build
	docker run --rm $(IMAGE):$(TAG) workspace-versions

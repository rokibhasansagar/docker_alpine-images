### All-In-One GNU Make Script to Handle All The Image Builds

## SHELL, use bash instead of sh
SHELL := /bin/bash

## Variables, ':=' for expandable commands, '=' for static string
BUILDX_VER = v0.4.1

DOCKER_USERNAME = fr3akyphantom
#DOCKER_PASSWORD <<< from internal S3CR3T
#DOCKER_SLUG := $(DOCKER_USERNAME)/$(IMAGE_NAME)

BUILD_TIME := $(shell date --date='TZ="Asia/Dhaka"' +"%Y-%m-%dT%H:%M:%S%Z")
SNAP_DATE := $(shell date -d 'TZ="Asia/Dhaka"' +"%y.%m.%d")

PACKAGES := "alpine-base"
#IMAGE_NAME <<< from PACKAGES[@]
#IMAGE_DESC <<< $(sed '5q;d' $$i/README.md | sed -e 's/^.........//' -e 's/.........$//')

REL_VER = 1.0

### Docker Build Labels
LABELS := \
	--label org.label-schema.build-date=$(BUILD_TIME) \
	--label org.label-schema.name="$(IMAGE_NAME)" \
	--label org.label-schema.description="$(IMAGE_DESC)" \
	--label org.label-schema.url="https://rokibhasansagar.github.io/" \
	--label org.label-schema.vcs-ref=$(shell git rev-parse --short HEAD) \
	--label org.label-schema.vcs-url=$(shell git remote get-url origin) \
	--label org.label-schema.vendor="Rokib Hasan Sagar" \
	--label org.label-schema.version=$(REL_VER) \
	--label org.label-schema.schema-version="1.0"

### Docker Build Flags
BUILDFLAGS := \
	--compress --no-cache --rm --force-rm --push \
	--platform linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6

### .PHONY
.PHONY: docker_login setup_qemu install_buildx prepare_buildx build_images
### Definitions/Functions
docker_login:
	@docker login -u $(DOCKER_USERNAME) -p "$(DOCKER_PASSWORD)"

setup_qemu :
	@echo -e "\n[i] Fetching QEMU Binary Supported Image..."
	@docker pull multiarch/qemu-user-static:register
	@docker run --privileged multiarch/qemu-user-static:latest --reset

install_buildx:
	@echo -e "\n[+] Installing Docker Buildx..."
	@mkdir -vp ~/.docker/cli-plugins/ ~/dockercache
	curl --silent -L "https://github.com/docker/buildx/releases/download/$(BUILDX_VER)/buildx-$(BUILDX_VER).linux-amd64" > ~/.docker/cli-plugins/docker-buildx
	@chmod a+x ~/.docker/cli-plugins/docker-buildx
	@export DOCKER_CLI_EXPERIMENTAL=enabled

prepare_buildx:
	@echo -e "\n[i] Preparing Docker Buildx Build Context..."
	@docker context create old-style
	@docker buildx create old-style --use --platform linux/amd64,linux/arm64/v8,linux/arm/v7,linux/arm/v6 --buildkitd-flags '--debug'
	@docker buildx inspect --bootstrap

dockerhub_desc:
	@export DOCKER_REPOSITORY=$(DOCKER_USERNAME)/$(IMAGE_NAME)
	@README_FILEPATH=$(IMAGE_NAME)/README.md
	# Acquire a token for the Docker Hub API
	LOGIN_PAYLOAD="{\"username\": \"${DOCKER_USERNAME}\", \"password\": \"${DOCKER_PASSWORD}\"}"
	TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d ${LOGIN_PAYLOAD} https://hub.docker.com/v2/users/login/ | jq -r .token)
	# Send a PATCH request to update the description of the repository
	REPO_URL="https://hub.docker.com/v2/repositories/${DOCKER_REPOSITORY}/"
	RESPONSE_CODE=$(curl -s --write-out %{response_code} --output /dev/null -H "Authorization: JWT ${TOKEN}" -X PATCH --data-urlencode full_description@${README_FILEPATH} ${REPO_URL})
	@echo "Received response code: $RESPONSE_CODE"

docker_buildx_build:
	@echo -e "\n[i] Starting Build..."
	@docker Buildx build . \
		--file $(IMAGE_NAME)/Dockerfile \
		$(BUILDFLAGS) $(LABELS) \
		-t $(DOCKER_USERNAME)/$(IMAGE_NAME):$(SNAP_DATE) \
		-t $(DOCKER_USERNAME)/$(IMAGE_NAME):latest
	@echo -e "\n[+] Congratulations! Build Finished."
	@echo -e "\n\n [i] Updating Docker Repository Description..."
	$(MAKE) dockerhub_desc

build_images: $(PACKAGES)
	# check changes
	@export CURRENT_SHA=$(git rev-parse HEAD)
	@for i in $(PACKAGES); do \
		export IMAGE_NAME=$$i; \
		export IMAGE_DESC=$(sed '5q;d' $$i/README.md | sed -e 's/^.........//' -e 's/.........$//'); \
		export PKG_SHA=$(git log -n1 --format=format:"%H" -- $$i/Dockerfile); \
		if [ "$PKG_SHA" = "$CURRENT_SHA" ]; then \
			# Build-push
			$(MAKE) docker_buildx_build; \
		else \
			echo -e "\n[!] $$i is Already Up-to-date."; \
		fi; \
	done

build_single_image:
	# Usage: `make IMAGE_NAME="alpine-glibc" build_single_image`
	@export IMAGE_NAME=$(IMAGE_NAME)
	@export IMAGE_DESC=$(sed '5q;d' $(IMAGE_NAME)/README.md | sed -e 's/^.........//' -e 's/.........$//'); \
	$(MAKE) docker_buildx_build

force_build_images:
	# force to build everything
	@for i in $(PACKAGES); do \
		export IMAGE_NAME=$$i; \
		export IMAGE_DESC=$(sed '5q;d' $$i/README.md | sed -e 's/^.........//' -e 's/.........$//'); \
		$(MAKE) docker_buildx_build; \
	done

test_image:
	@docker pull $(DOCKER_USERNAME)/$(IMAGE_NAME):latest
	@docker run --rm -i --privileged $(DOCKER_USERNAME)/$(IMAGE_NAME):latest \
		--name docker_$(IMAGE_NAME) --hostname $(IMAGE_NAME) -c 64 -m 256m \
		sh -ec 'cat /etc/os-release'

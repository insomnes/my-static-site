serve:
	docker run --rm --pull=always -it \
		-u $(shell id -u):$(shell id -g) \
		-p 8000:8000 \
		-v $(shell pwd):/docs \
		squidfunk/mkdocs-material \
		serve \
		--dev-addr=0.0.0.0:8000 \
		--strict

build:
	docker run --rm --pull=always -it \
		-v $(shell pwd):/docs \
		squidfunk/mkdocs-material build \
		--strict \
		--site-dir public

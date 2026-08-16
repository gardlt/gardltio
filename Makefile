.PHONY: serve build clean serve-docker stop

# Blowfish v2 requires a recent Hugo extended. CI uses 'latest'.
HUGO ?= hugo

serve:
	$(HUGO) server -D --disableFastRender

build:
	$(HUGO) --minify

clean:
	rm -rf public resources/_gen

# Fallback if Hugo isn't installed locally. Note: $$(pwd) — a single $ would be
# expanded by make (as an empty variable), not by the shell.
serve-docker:
	docker run --name hugo --rm -v $$(pwd):/src -p 1313:1313 \
		hugomods/hugo:exts hugo server -D --bind 0.0.0.0

stop:
	docker rm -f hugo

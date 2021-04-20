
serv:
	docker run --name hugo -d -v $(pwd):/src -p 1313:1313 klakegg/hugo:0.82.0 serve -D
stop:
	docker rm -f hugo

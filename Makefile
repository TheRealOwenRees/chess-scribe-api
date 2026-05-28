run:
	dune build && dune exec ./_build/default/bin/main.exe DREAM_ENV=production

run-dev:
	dune build && dune exec ./_build/default/bin/main.exe DREAM_ENV=development
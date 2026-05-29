run:
	dune build && dune exec ./_build/default/bin/main.exe DREAM_ENV=production

run-dev:
	find . -name "*.ml" -o -path "./static/*" | entr -r dune exec ./_build/default/bin/main.exe DREAM_ENV=development
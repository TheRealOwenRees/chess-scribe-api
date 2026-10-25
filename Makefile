run:
	dune build && DREAM_ENV=production dune exec ./_build/default/bin/main.exe

run-dev:
	find . -name "*.ml" -o -path "./static/*" | entr -r env DREAM_ENV=development dune exec ./_build/default/bin/main.exe
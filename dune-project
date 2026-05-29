(lang dune 3.21)

(name chess-scribe-api)

(generate_opam_files true)

(source
 (github therealowenrees/chess-scribe-api))

(authors "Owen Rees<owenrees.dev@gmail.com>")

(maintainers "Owen Rees <owenrees.dev@gmail.com>")

(license AGPL-3.0-or-later)

(documentation https://github.com/therealowenrees/chess-scribe-api/README.md)

(package
 (name chess-scribe-api)
 (synopsis "API for chess-scribe.org")
 (description
  "The backend that powers chess-scribe.org. Convert chess PGN files into PDFs.")
 (depends
  ocaml
  (dream
   (>= "1.0.0~alpha8"))
  pgn_to_tex)
 (tags
  ("chess" "pgn" "pdf")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html

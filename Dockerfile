# --- STAGE 1: Build the native OCaml binary ---
FROM ocaml/opam:debian-12-ocaml-5.4 AS builder
USER opam
WORKDIR /app
COPY --chown=opam:opam dune-project ./
RUN opam update && opam install -y dune dream
COPY --chown=opam:opam . .
RUN opam exec -- dune build bin/main.exe

# --- STAGE 2: Lightweight runtime environment ---
FROM debian:12-slim
WORKDIR /app

# Install native system dependencies and a minimal TeX Live profile
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libev4 \
    ca-certificates \
    #     texlive-latex-base \
    #     texlive-latex-recommended \
    #     texlive-fonts-recommended \
    #     # tlmgr is the TeX Live package manager; we use it to grab chess assets
    #     texlive-games \ 
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled native OCaml binary from Stage 1
COPY --from=builder /app/_build/default/bin/main.exe ./server

# Copy the static assets folder
COPY ./static ./static

EXPOSE 8080
CMD ["./server"]
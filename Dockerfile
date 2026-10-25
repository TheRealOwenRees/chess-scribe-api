# --- STAGE 1: Build the native OCaml binary ---
# ocaml/opam:debian-13-ocaml-5.4
FROM ocaml/opam@sha256:f44a0401719551c26b8bdd990c5353aeb304f2896c1a4cc8d9159e95ab4446a2 AS builder
USER opam
WORKDIR /app
RUN cd /home/opam/opam-repository && git pull origin master
COPY --chown=opam:opam dune-project ./

RUN opam pin add pgn_to_tex 0.1.0 -y && \
    opam pin add dream 1.0.0 -y

RUN opam update && opam install -y dune dream pgn_to_tex
COPY --chown=opam:opam . .
RUN opam exec -- dune build bin/main.exe

# --- STAGE 2: Lightweight runtime environment ---
# debian:13.7-slim
FROM debian@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f
WORKDIR /app

# Configure apt to retry downloads up to 3 times if a packet gets corrupted
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries

# 1. Install native system dependencies and a minimal TeX Live profile
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libev4 \
    ca-certificates \
    wget \
    tar \
    perl \
    && rm -rf /var/lib/apt/lists/*

# 2. Download and run the TeX Live CTAN installer script
RUN wget --tries=5 https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar -xzf install-tl-unx.tar.gz && \
    rm install-tl-unx.tar.gz && \
    cd install-tl-* && \
    echo "selected_scheme scheme-basic" > profile && \
    ./install-tl -profile profile && \
    cd .. && \
    rm -rf install-tl-*

# 3. FIX: Ensure the dynamic path to tlmgr matches whatever year CTAN is currently on
ENV PATH="/usr/local/texlive/2026/bin/x86_64-linux:${PATH}"
ENV PATH="/usr/local/texlive/2025/bin/x86_64-linux:${PATH}"
# Fallback to absolute standard binary bin location
ENV PATH="/usr/local/texlive/bin/x86_64-linux:${PATH}"

# 4. Install TexLive packages needed for rendering a chess game
RUN tlmgr install parskip pgf chessboard etoolbox ifmtarg xifthen skaknew lambda-lists xkeyval chessfss skak xskak

#5. Copy preamble source and regenerate the format file
COPY ./preambles ./preambles
RUN cd preambles && pdflatex -ini -jobname="chess" "&pdflatex" chess.tex

# 6. Copy server binary and static assets
COPY --from=builder /app/_build/default/bin/main.exe ./server
COPY ./static ./static

EXPOSE 8080
CMD ["./server"]
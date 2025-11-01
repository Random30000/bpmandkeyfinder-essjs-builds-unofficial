FROM emscripten/emsdk:3.1.46

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    cmake \
    python3 \
    make \
    nodejs \
    npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work

COPY package.json package-lock.json* ./
RUN if [ -f package.json ]; then npm install --ignore-scripts; fi

COPY . .

CMD ["bash"]

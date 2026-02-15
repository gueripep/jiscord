FROM ghcr.io/cirruslabs/flutter as builder
RUN sudo apt update && sudo apt install curl wget jq build-essential -y

WORKDIR /tmp
RUN wget https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64.tar.gz
RUN tar -xzvf ./yq_linux_amd64.tar.gz
RUN mv yq_linux_amd64 /usr/bin/yq

COPY . /app
WORKDIR /app
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
RUN apt-get update && apt-get install -y dos2unix
RUN dos2unix ./scripts/prepare-web.sh
RUN chmod +x ./scripts/prepare-web.sh
RUN cat ./scripts/prepare-web.sh
RUN ./scripts/prepare-web.sh
COPY config.* /app/
RUN flutter pub get
RUN flutter build web --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/ --release --source-maps

FROM docker.io/nginx:alpine
RUN rm -rf /usr/share/nginx/html
COPY --from=builder /app/build/web /usr/share/nginx/html

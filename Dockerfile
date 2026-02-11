# Stage to copy the code and fetch dependencies 
# try to keep the debian version in sync with the distroless version
FROM golang:1.26-bookworm AS base

ARG VERSION=development

WORKDIR /work

COPY go.mod ./
COPY go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=cache,target=/root/.cache/go-build/ \
    go mod download

COPY main.go ./
COPY pkg/ ./pkg

# Stage to test the code
FROM base AS test

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=cache,target=/root/.cache/go-build/ \
    go vet -v ./...

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=cache,target=/root/.cache/go-build/ \
    go test -race -v -coverprofile=cover.out -covermode=atomic ./...

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=cache,target=/root/.cache/go-build/ \
    go tool cover -html cover.out -o cover.html

FROM scratch AS coverage

COPY --from=test /work/cover.html coverage.html
COPY --from=test /work/cover.out  coverage.out

# Stage to build the binary
FROM base AS build

RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=cache,target=/root/.cache/go-build/ \
    CGO_ENABLED=0 go build -ldflags="-X 'github.com/tmeire/go-web-scaffold/environment.Version=${VERSION}'" -o app .

# Stage with the production binary
FROM gcr.io/distroless/static-debian12 AS production

COPY --from=build /work/app /

# port for pprof
EXPOSE 6060
# port for the actual app
EXPOSE 8080
# port for the prometheus metrics
EXPOSE 9090

CMD ["/app"]
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /bridge

FROM scratch
COPY --from=build /bridge /bridge
ENTRYPOINT ["/bridge"]

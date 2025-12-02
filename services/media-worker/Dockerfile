FROM golang:1.22-alpine AS builder

WORKDIR /build

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o media-worker ./cmd/worker

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata ffmpeg

WORKDIR /app

COPY --from=builder /build/media-worker .

# Create temp directory for processing
RUN mkdir -p /tmp/worker && chmod 777 /tmp/worker

CMD ["./media-worker"]

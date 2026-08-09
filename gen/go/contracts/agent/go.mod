module github.com/kobecal/protos/gen/go/contracts/agent

go 1.24.0

require (
	github.com/kobecal/protos/gen/go/contracts/common v0.0.0-00010101000000-000000000000
	google.golang.org/genproto/googleapis/api v0.0.0-20241104194629-dd2ea8efbc28
	google.golang.org/protobuf v1.36.11
)

replace github.com/kobecal/protos/gen/go/contracts/common => ../common
